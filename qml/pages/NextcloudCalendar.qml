import QtQuick 2.12
import Lomiri.Components 1.3
import QtQuick.Controls 2.2 as QControls
import Lomiri.Components.Popups 1.3
import Lomiri.Components.Themes 1.3
import "nextcloudcalendar"

// Calendar of the Nextcloud account: day, week, month and year views, with
// creation, modification and deletion of events through CalDAV.
Item {
    id: calendarPage
    anchors.fill: parent

    property int viewMode: 2       // 0 day, 1 week, 2 month, 3 year
    property date currentDate: new Date()

    // Account of this page, stored in the page data (pageIndex injected by
    // Main.qml). The global settings are the fallback for pages created
    // before per-page configuration existed.
    property int pageIndex: -1
    // Accounts of this page: [{url, user, password, href, name}]
    property var accounts: []
    // Account receiving a new event when several are configured.
    property int targetAccount: 0

    // The day view feeds a ListModel: a ListView whose model is a JS array
    // rebuilt by a function loops forever (binding loop on "model").
    ListModel { id: dayModel }

    // Week grid: one model for the timed blocks (position computed from the
    // start/duration) and one for the all-day chips.
    ListModel { id: weekTimedModel }
    ListModel { id: weekAllDayModel }

    readonly property real weekGutterWidth: units.gu(6.5)
    readonly property real weekHourHeight: units.gu(5)
    readonly property real weekAllDayRowHeight: units.gu(2.6)
    property int weekAllDayRows: 1

    // Content of the event dialog.
    property int editingIndex: -1
    property string eventSummary: ""
    property string eventLocation: ""
    property string eventDescription: ""
    property string eventStartDate: ""
    property string eventStartTime: ""
    property string eventEndDate: ""
    property string eventEndTime: ""
    property bool eventAllDay: false
    // Month shown by the date picker, the selected day and the field it
    // belongs to.
    property string datePickerTarget: ""
    property date datePickerMonth: new Date()
    property date datePickerSelected: new Date()
    // Error shown in the event dialog. It is kept on the page because the
    // dialog is a separate component: an id of the dialog is not in scope
    // from the functions of the page.
    property string eventError: ""
    // PopupUtils.open() returns the popup instance, not the component: the
    // instance is needed to close a dialog from a function of the page (the
    // ids inside a Component are not in scope here).
    property var eventDialogObject: null
    property var datePickerObject: null

    readonly property var weekDayNames: [
        i18n.tr("Mon"), i18n.tr("Tue"), i18n.tr("Wed"), i18n.tr("Thu"),
        i18n.tr("Fri"), i18n.tr("Sat"), i18n.tr("Sun")
    ]

    Component.onCompleted: {
        loadAccounts()
        refreshDayModel()
        rebuildWeekModels()
        NextcloudCalendarModel.refresh(60, 180)
    }

    onVisibleChanged: {
        if (visible) {
            loadAccounts()
            NextcloudCalendarModel.refresh(60, 180)
        }
    }

    function pageConfig() {
        if (pageIndex >= 0 && pageIndex < launchermodular.pageModel.count) {
            var data = launchermodular.pageModel.get(pageIndex).data
            if (data && typeof data === "object")
                return data
        }
        return ({})
    }

    // Several accounts can be attached to one page (page data
    // "nextcloudAccounts"). A page without any falls back to the single account
    // of its data, then to the global settings.
    // The model is shared by all the calendar pages and the Event widget: it
    // holds the union of their accounts, so both always see the same events.
    // One configured Nextcloud account can expose several calendars; the
    // model works with one entry per calendar.
    function expandAccounts(stored) {
        var result = []
        for (var index = 0; index < stored.length; index++) {
            var account = stored[index]
            if (!account)
                continue
            var calendars = account.calendars || []
            var expanded = false
            for (var calendarIndex = 0; calendarIndex < calendars.length; calendarIndex++) {
                if (!calendars[calendarIndex] || !calendars[calendarIndex].href)
                    continue
                result.push({ url: account.url, user: account.user,
                              password: account.password,
                              href: calendars[calendarIndex].href,
                              name: calendars[calendarIndex].name || "" })
                expanded = true
            }
            if (!expanded && account.href) {
                result.push({ url: account.url, user: account.user,
                              password: account.password,
                              href: account.href, name: account.name || "" })
            }
        }
        return result
    }

    function loadAccounts() {
        var stored = []
        for (var index = 0; index < launchermodular.pageModel.count; index++) {
            var page = launchermodular.pageModel.get(index)
            if (page.name !== "NextcloudCalendar.qml")
                continue
            var data = page.data || {}
            // Configuration by stable uid, with the page data as legacy.
            var config = (page.uid && page.uid.length > 0)
                    ? launchermodular.getPageConfig(page.uid) : ({})
            var raw = config.nextcloudAccountsJson || data.nextcloudAccountsJson
            if (raw && raw.length > 0) {
                try { stored = stored.concat(JSON.parse(raw)) } catch (error) { }
            } else if ((config.nextcloudAccounts && config.nextcloudAccounts.length > 0)
                       || (data.nextcloudAccounts && data.nextcloudAccounts.length > 0)) {
                var legacy = (config.nextcloudAccounts && config.nextcloudAccounts.length > 0)
                        ? config.nextcloudAccounts : data.nextcloudAccounts
                for (var accountIndex = 0; accountIndex < legacy.length; accountIndex++)
                    stored.push(legacy[accountIndex])
            } else if ((config.nextcloudUrl || data.nextcloudUrl)
                       && (config.nextcloudUser || data.nextcloudUser)
                       && (config.nextcloudPassword || data.nextcloudPassword)) {
                stored.push({ url: config.nextcloudUrl || data.nextcloudUrl,
                              user: config.nextcloudUser || data.nextcloudUser,
                              password: config.nextcloudPassword || data.nextcloudPassword,
                              href: config.nextcloudCalendarHref || data.nextcloudCalendarHref || "",
                              name: "" })
            }
        }
        if (stored.length === 0 && launchermodular.settings.nextcloudAccountsJson.length > 0) {
            try { stored = JSON.parse(launchermodular.settings.nextcloudAccountsJson) } catch (error) { stored = [] }
        }
        if (stored.length === 0 && launchermodular.settings.nextcloudUrl
                && launchermodular.settings.nextcloudUser && launchermodular.settings.nextcloudPassword) {
            stored.push({ url: launchermodular.settings.nextcloudUrl,
                          user: launchermodular.settings.nextcloudUser,
                          password: launchermodular.settings.nextcloudPassword,
                          href: launchermodular.settings.nextcloudCalendarHref || "", name: "" })
        }
        accounts = expandAccounts(stored)
        if (targetAccount >= accounts.length)
            targetAccount = 0
        NextcloudCalendarModel.configureAccounts(accounts)
    }

    onCurrentDateChanged: {
        refreshDayModel()
        if (viewMode === 1) {
            rebuildWeekModels()
            scrollWeekToWorkingHours()
        }
    }
    onViewModeChanged: {
        if (viewMode === 0)
            refreshDayModel()
        if (viewMode === 1) {
            rebuildWeekModels()
            Qt.callLater(scrollWeekToWorkingHours)
        }
    }

    Connections {
        target: NextcloudCalendarModel
        function onUpdated() {
            calendarPage.refreshDayModel()
            calendarPage.rebuildWeekModels()
        }
    }


    // --- dates -------------------------------------------------------------

    function startOfDay(date) {
        var copy = new Date(date)
        copy.setHours(0, 0, 0, 0)
        return copy
    }

    // Monday at 00:00 of the week holding date.
    function startOfWeek(date) {
        var day = startOfDay(date)
        var offset = (day.getDay() + 6) % 7
        return addDays(day, -offset)
    }

    function weekDayDate(index) {
        return addDays(startOfWeek(currentDate), index)
    }

    function addDays(date, days) {
        var copy = new Date(date)
        copy.setDate(copy.getDate() + days)
        return copy
    }

    function sameDay(first, second) {
        return first.getFullYear() === second.getFullYear()
                && first.getMonth() === second.getMonth()
                && first.getDate() === second.getDate()
    }

    function refreshDayModel() {
        dayModel.clear()
        var events = calendarPage.eventsForDay(calendarPage.currentDate)
        for (var index = 0; index < events.length; index++) {
            var event = events[index]
            dayModel.append({
                summary: event.event.summary,
                description: event.event.description,
                location: event.event.location,
                start: event.event.start,
                end: event.event.end,
                allDay: event.event.allDay,
                sourceIndex: event.index
            })
        }
    }

    function eventsForDay(day) {
        var result = []
        var from = startOfDay(day).getTime()
        var to = from + 86400000
        // events.count is read here on purpose: the binding of the caller is
        // refreshed when the model is refilled.
        for (var index = 0; index < NextcloudCalendarModel.events.count; index++) {
            var event = NextcloudCalendarModel.events.get(index)
            // Overlap, not only the start day: an event spanning several days
            // (including an all-day event) appears on every day it covers.
            if (event.end > from && event.start < to)
                result.push({ index: index, event: event })
        }
        return result
    }

    // Fills the two week models: timed events keep their start and duration
    // (clamped to the day), all-day events go to the strip above the grid.
    function rebuildWeekModels() {
        weekTimedModel.clear()
        weekAllDayModel.clear()
        weekAllDayRows = 1
        var start = startOfWeek(currentDate)
        for (var dayIndex = 0; dayIndex < 7; dayIndex++) {
            var day = addDays(start, dayIndex)
            var dayStart = startOfDay(day).getTime()
            var events = eventsForDay(day)
            var allDayRows = 0
            for (var eventIndex = 0; eventIndex < events.length; eventIndex++) {
                var event = events[eventIndex].event
                if (event.allDay) {
                    weekAllDayModel.append({
                        dayIndex: dayIndex,
                        row: allDayRows,
                        label: event.summary,
                        sourceIndex: events[eventIndex].index
                    })
                    allDayRows++
                    continue
                }
                var from = Math.max(event.start, dayStart)
                var to = Math.min(event.end, dayStart + 86400000)
                if (to <= from)
                    to = from + 30 * 60000
                weekTimedModel.append({
                    dayIndex: dayIndex,
                    startMinutes: (from - dayStart) / 60000,
                    durationMinutes: Math.max((to - from) / 60000, 20),
                    label: event.summary,
                    timeText: Qt.formatTime(new Date(event.start))
                              + " – " + Qt.formatTime(new Date(event.end)),
                    sourceIndex: events[eventIndex].index
                })
            }
            weekAllDayRows = Math.max(weekAllDayRows, allDayRows)
        }
    }

    function scrollWeekToWorkingHours() {
        var maxY = Math.max(0, weekFlick.contentHeight - weekFlick.height)
        weekFlick.contentY = Math.min(7 * weekHourHeight, maxY)
    }

    // 42 cells (six weeks) starting on a Monday.
    function monthCells(date) {
        var first = new Date(date.getFullYear(), date.getMonth(), 1)
        var offset = (first.getDay() + 6) % 7
        var start = addDays(first, -offset)
        var cells = []
        for (var index = 0; index < 42; index++) {
            var day = addDays(start, index)
            cells.push({ day: day, inMonth: day.getMonth() === date.getMonth() })
        }
        return cells
    }

    function periodLabel() {
        if (viewMode === 0)
            return Qt.formatDate(currentDate, Qt.SystemLocaleLongDate)
        if (viewMode === 1) {
            var start = startOfWeek(currentDate)
            var end = addDays(start, 6)
            return Qt.formatDate(start, "d MMM") + " – "
                    + Qt.formatDate(end, "d MMM yyyy")
        }
        if (viewMode === 2)
            return Qt.formatDate(currentDate, "MMMM yyyy")
        return currentDate.getFullYear().toString()
    }

    // Return to the current date whatever the view (day, week, month, year).
    function goToToday() {
        currentDate = new Date()
        refreshDayModel()
    }

    function move(direction) {
        if (viewMode === 0)
            currentDate = addDays(currentDate, direction)
        else if (viewMode === 1)
            currentDate = addDays(currentDate, 7 * direction)
        else if (viewMode === 2)
            currentDate = new Date(currentDate.getFullYear(), currentDate.getMonth() + direction, 1)
        else
            currentDate = new Date(currentDate.getFullYear() + direction, 0, 1)
    }

    // --- event dialog ------------------------------------------------------

    function formatDateInput(date) {
        return Qt.formatDate(date, "yyyy-MM-dd")
    }

    // ISO is kept in the fields (parsing is unambiguous), the dialog shows
    // the date in the format of the user's locale.
    function displayDate(text) {
        var parsed = new Date(String(text) + "T12:00:00")
        if (isNaN(parsed.getTime()))
            return text
        return Qt.formatDate(parsed)
    }

    function formatTimeInput(date) {
        return Qt.formatTime(date, "HH:mm")
    }

    function openNewEvent(day) {
        var start = startOfDay(day || currentDate)
        start.setHours(9, 0, 0, 0)
        var end = new Date(start.getTime() + 3600000)
        editingIndex = -1
        eventError = ""
        eventSummary = ""
        eventLocation = ""
        eventDescription = ""
        eventStartDate = formatDateInput(start)
        eventStartTime = formatTimeInput(start)
        eventEndDate = formatDateInput(end)
        eventEndTime = formatTimeInput(end)
        eventAllDay = false
        eventDialogObject = PopupUtils.open(eventDialog)
    }

    function openEvent(index) {
        var event = NextcloudCalendarModel.events.get(index)
        if (!event)
            return
        editingIndex = index
        eventSummary = event.summary
        eventLocation = event.location
        eventDescription = event.description
        var start = new Date(event.start)
        var end = new Date(event.end)
        eventStartDate = formatDateInput(start)
        eventStartTime = formatTimeInput(start)
        eventEndDate = formatDateInput(end)
        eventEndTime = formatTimeInput(end)
        eventAllDay = event.allDay
        eventError = ""
        eventDialogObject = PopupUtils.open(eventDialog)
    }

    function parseDateTime(dateText, timeText) {
        var parsed = new Date(dateText + "T" + (eventAllDay ? "00:00" : timeText) + ":00")
        return isNaN(parsed.getTime()) ? null : parsed
    }

    // The end cannot be before the start. Called after a date is picked, after
    // a time is edited and when "All day" is switched.
    function ensureEndAfterStart() {
        if (eventAllDay) {
            if (eventStartDate.length === 0)
                return
            var startDay = new Date(eventStartDate + "T12:00:00")
            if (isNaN(startDay.getTime()))
                return
            if (eventEndDate.length === 0 || eventEndDate <= eventStartDate)
                eventEndDate = formatDateInput(addDays(startOfDay(startDay), 1))
            eventEndTime = "00:00"
            return
        }
        var start = parseDateTime(eventStartDate, eventStartTime)
        var end = parseDateTime(eventEndDate, eventEndTime)
        if (!start || !end)
            return
        if (end.getTime() <= start.getTime()) {
            var adjusted = new Date(start.getTime() + 3600000)
            eventEndDate = formatDateInput(adjusted)
            eventEndTime = formatTimeInput(adjusted)
        }
    }

    function applyAllDay() {
        if (eventAllDay) {
            ensureEndAfterStart()
            return
        }
        // Switching back to timed events: keep at least one hour.
        var start = parseDateTime(eventStartDate, eventStartTime)
        if (!start)
            return
        if (eventEndDate === "") {
            var end = new Date(start.getTime() + 3600000)
            eventEndDate = formatDateInput(end)
            eventEndTime = formatTimeInput(end)
        } else {
            ensureEndAfterStart()
        }
    }

    function openDatePicker(target) {
        datePickerTarget = target
        var text = target === "start" ? eventStartDate : eventEndDate
        var parsed = new Date(text + "T12:00:00")
        datePickerSelected = isNaN(parsed.getTime()) ? new Date() : parsed
        datePickerMonth = new Date(datePickerSelected.getFullYear(),
                                   datePickerSelected.getMonth(), 1)
        datePickerObject = PopupUtils.open(datePickerDialog)
    }

    function shiftPickerMonth(direction) {
        datePickerMonth = new Date(datePickerMonth.getFullYear(),
                                   datePickerMonth.getMonth() + direction, 1)
    }

    // A click on a day selects it, writes the field and closes the dialog.
    function pickDate(day) {
        datePickerSelected = day
        var formatted = Qt.formatDate(day, "yyyy-MM-dd")
        if (datePickerTarget === "start")
            eventStartDate = formatted
        else if (formatted < eventStartDate)
            eventEndDate = eventStartDate   // never before the start
        else
            eventEndDate = formatted
        ensureEndAfterStart()
        if (datePickerObject) PopupUtils.close(datePickerObject)
    }

    function saveEvent() {
        // Last line of defence: the fields may still hold an end before the
        // start if they were not left before pressing Save.
        ensureEndAfterStart()
        var start = parseDateTime(eventStartDate, eventStartTime)
        var end = parseDateTime(eventEndDate, eventEndTime)
        if (!start || !end) {
            eventError = i18n.tr("Invalid date or time")
            return
        }
        if (end.getTime() <= start.getTime()) {
            eventError = i18n.tr("The end must be after the start")
            return
        }
        if (eventSummary.trim().length === 0) {
            eventError = i18n.tr("The title is required")
            return
        }
        eventError = ""
        var fields = {
            summary: eventSummary,
            location: eventLocation,
            description: eventDescription,
            start: start,
            end: end,
            allDay: eventAllDay
        }
        var done = function (success, code) {
            if (!success) {
                eventError = i18n.tr("The server refused the change (HTTP %1)").arg(code)
                return
            }
            if (eventDialogObject) PopupUtils.close(eventDialogObject)
            NextcloudCalendarModel.refresh(60, 180)
        }
        if (editingIndex >= 0)
            NextcloudCalendarModel.updateEvent(editingIndex, fields, done)
        else
            NextcloudCalendarModel.createEventIn(targetAccount, fields, done)
    }

    // --- header ------------------------------------------------------------

    Row {
        id: toolbar
        width: parent.width
        height: units.gu(5)
        spacing: units.gu(0.5)

        Rectangle {
            width: units.gu(5)
            height: units.gu(4)
            color: "transparent"
            Icon {
                anchors.centerIn: parent
                name: "go-previous"
                color: launchermodular.settings.textColor
                width: units.gu(2)
                height: units.gu(2)
            }
            MouseArea {
                anchors.fill: parent
                onClicked: calendarPage.move(-1)
            }
        }
        Label {
            width: toolbar.width - units.gu(22)
            height: toolbar.height
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            color: launchermodular.settings.textColor
            text: calendarPage.periodLabel()
        }
        Rectangle {
            width: units.gu(5)
            height: units.gu(4)
            color: "transparent"
            Icon {
                anchors.centerIn: parent
                name: "go-next"
                color: launchermodular.settings.textColor
                width: units.gu(2)
                height: units.gu(2)
            }
            MouseArea {
                anchors.fill: parent
                onClicked: calendarPage.move(1)
            }
        }
        Rectangle {
            width: units.gu(5)
            height: units.gu(4)
            color: "transparent"
            Icon {
                anchors.centerIn: parent
                name: "calendar-today"
                color: launchermodular.settings.textColor
                width: units.gu(2)
                height: units.gu(2)
            }
            MouseArea {
                anchors.fill: parent
                onClicked: calendarPage.goToToday()
            }
        }
        Rectangle {
            width: units.gu(5)
            height: units.gu(4)
            color: "transparent"
            Icon {
                anchors.centerIn: parent
                name: "add"
                color: launchermodular.settings.textColor
                width: units.gu(2)
                height: units.gu(2)
            }
            MouseArea {
                anchors.fill: parent
                onClicked: calendarPage.openNewEvent(calendarPage.currentDate)
            }
        }
    }

    Row {
        id: modeBar
        anchors.top: toolbar.bottom
        width: parent.width
        height: units.gu(4)
        spacing: units.gu(0.5)

        Repeater {
            model: [i18n.tr("Day"), i18n.tr("Week"), i18n.tr("Month"), i18n.tr("Year")]
            Rectangle {
                width: (modeBar.width - units.gu(1.5)) / 4
                height: modeBar.height
                radius: units.gu(0.4)
                color: calendarPage.viewMode === index ? "#E95420" : "#33ffffff"

                Label {
                    anchors.centerIn: parent
                    text: modelData
                    color: "#ffffff"
                    fontSize: "small"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: calendarPage.viewMode = index
                }
            }
        }
    }

    Label {
        id: statusLabel
        anchors.top: modeBar.bottom
        width: parent.width
        height: units.gu(2.5)
        horizontalAlignment: Text.AlignHCenter
        color: "#ED3146"
        text: {
            if (!NextcloudCalendarModel.configured)
                return i18n.tr("Configure the Nextcloud account in the page settings.")
            if (NextcloudCalendarModel.lastError.length > 0)
                return NextcloudCalendarModel.lastError
            if (NextcloudCalendarModel.syncing)
                return i18n.tr("Synchronising…")
            return ""
        }
    }

    // --- month view --------------------------------------------------------

    Column {
        id: monthView
        anchors.top: statusLabel.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: viewMode === 2
        spacing: units.gu(0.2)

        Row {
            width: parent.width
            Repeater {
                model: calendarPage.weekDayNames
                Label {
                    width: monthView.width / 7
                    horizontalAlignment: Text.AlignHCenter
                    color: launchermodular.settings.textColor
                    fontSize: "x-small"
                    text: modelData
                }
            }
        }

        Grid {
            columns: 7
            Repeater {
                model: calendarPage.monthCells(calendarPage.currentDate)
                Rectangle {
                    id: monthCell
                    width: monthView.width / 7
                    height: units.gu(6)
                    color: modelData.inMonth ? "#22ffffff" : "transparent"
                    border.color: "#33ffffff"
                    border.width: 1

                    // Two event titles at most, in a ListModel: a Repeater fed
                    // by a function returning a JS array loops on "model".
                    ListModel { id: cellEvents }

                    function loadCellEvents() {
                        cellEvents.clear()
                        var events = calendarPage.eventsForDay(modelData.day)
                        for (var eventIndex = 0; eventIndex < events.length && eventIndex < 2; eventIndex++)
                            cellEvents.append({ summary: events[eventIndex].event.summary })
                    }

                    Component.onCompleted: loadCellEvents()
                    Connections {
                        target: NextcloudCalendarModel
                        function onUpdated() { monthCell.loadCellEvents() }
                    }

                    Rectangle {
                        width: parent.width
                        height: parent.height
                        color: calendarPage.sameDay(modelData.day, calendarPage.currentDate)
                               ? "#55E95420"
                               : (calendarPage.sameDay(modelData.day, new Date())
                                  ? "#33E95420" : "transparent")
                    }

                    Label {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: units.gu(0.3)
                        text: modelData.day.getDate()
                        fontSize: "x-small"
                        color: modelData.inMonth ? launchermodular.settings.textColor : "#88ffffff"
                    }

                    Column {
                        anchors.top: parent.top
                        anchors.topMargin: units.gu(2)
                        anchors.left: parent.left
                        anchors.right: parent.right
                        Repeater {
                            model: cellEvents
                            Label {
                                width: parent.width
                                elide: Text.ElideRight
                                fontSize: "x-small"
                                color: "#E95420"
                                text: summary
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        // Opening the day view on a click is the expected
                        // navigation; when the day is empty the day view shows
                        // "No events for this day" instead of a blank area.
                        onClicked: {
                            calendarPage.currentDate = modelData.day
                            calendarPage.viewMode = 0
                        }
                    }
                }
            }
        }
    }

    // --- week view ---------------------------------------------------------
    //
    // A time grid: hours down the left, the seven days across, timed events as
    // blocks whose height follows their duration.

    Item {
        id: weekView
        anchors.top: statusLabel.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: viewMode === 1

        readonly property real dayWidth: (width - calendarPage.weekGutterWidth) / 7

        Row {
            id: weekHeader
            width: parent.width
            height: units.gu(5)

            Item {
                width: calendarPage.weekGutterWidth
                height: parent.height
            }

            Repeater {
                model: 7
                Item {
                    width: weekView.dayWidth
                    height: weekHeader.height

                    property date day: calendarPage.weekDayDate(index)

                    Label {
                        anchors.centerIn: parent
                        text: Qt.formatDate(day, "ddd d")
                        color: calendarPage.sameDay(day, new Date())
                               ? "#E95420" : launchermodular.settings.textColor
                        font.pixelSize: units.gu(1.4)
                        font.bold: calendarPage.sameDay(day, new Date())
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            calendarPage.currentDate = day
                            calendarPage.viewMode = 0
                        }
                    }
                }
            }
        }

        // All-day events, above the scrolled grid.
        Item {
            id: allDayStrip
            anchors.top: weekHeader.bottom
            width: parent.width
            height: weekAllDayModel.count > 0
                    ? calendarPage.weekAllDayRows * calendarPage.weekAllDayRowHeight + units.gu(0.6)
                    : 0
            clip: true
            visible: height > 0

            Rectangle {
                anchors.fill: parent
                color: "#10FFFFFF"
            }

            Label {
                anchors.left: parent.left
                anchors.leftMargin: units.gu(1)
                anchors.top: parent.top
                anchors.topMargin: units.gu(0.8)
                text: i18n.tr("All day")
                color: "#AEA79F"
                font.pixelSize: units.gu(1.2)
            }

            Repeater {
                model: weekAllDayModel
                Rectangle {
                    x: calendarPage.weekGutterWidth + model.dayIndex * weekView.dayWidth + units.gu(0.2)
                    y: units.gu(0.3) + model.row * calendarPage.weekAllDayRowHeight
                    width: weekView.dayWidth - units.gu(0.4)
                    height: calendarPage.weekAllDayRowHeight - units.gu(0.4)
                    radius: units.gu(0.3)
                    color: "#33E95420"
                    border.width: 1
                    border.color: "#E95420"

                    Label {
                        anchors.fill: parent
                        anchors.margins: units.gu(0.4)
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                        color: "#FFFFFF"
                        font.pixelSize: units.gu(1.2)
                        text: model.label
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: calendarPage.openEvent(model.sourceIndex)
                    }
                }
            }
        }

        Flickable {
            id: weekFlick
            anchors.top: allDayStrip.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            contentWidth: width
            contentHeight: 24 * calendarPage.weekHourHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick

            Item {
                width: weekFlick.width
                height: weekFlick.contentHeight

                // Day columns, with today tinted.
                Repeater {
                    model: 7
                    Rectangle {
                        x: calendarPage.weekGutterWidth + index * weekView.dayWidth
                        width: weekView.dayWidth
                        height: parent.height
                        color: calendarPage.sameDay(calendarPage.weekDayDate(index), new Date())
                               ? "#12E95420" : "transparent"
                        border.width: 1
                        border.color: "#18FFFFFF"
                    }
                }

                // Hour lines and labels (locale time format).
                Repeater {
                    model: 24
                    Item {
                        y: index * calendarPage.weekHourHeight
                        width: parent.width
                        height: calendarPage.weekHourHeight

                        Rectangle {
                            x: calendarPage.weekGutterWidth
                            width: parent.width - calendarPage.weekGutterWidth
                            height: 1
                            color: "#22FFFFFF"
                        }

                        Label {
                            x: 0
                            width: calendarPage.weekGutterWidth - units.gu(0.8)
                            horizontalAlignment: Text.AlignRight
                            text: Qt.formatTime(new Date(2020, 0, 1, index, 0))
                            color: "#AEA79F"
                            font.pixelSize: units.gu(1.1)
                        }
                    }
                }

                // Timed events.
                Repeater {
                    model: weekTimedModel
                    Rectangle {
                        x: calendarPage.weekGutterWidth + model.dayIndex * weekView.dayWidth + units.gu(0.15)
                        width: weekView.dayWidth - units.gu(0.3)
                        y: model.startMinutes / 60 * calendarPage.weekHourHeight + 1
                        height: Math.max(model.durationMinutes / 60 * calendarPage.weekHourHeight - 2,
                                         units.gu(2.2))
                        radius: units.gu(0.3)
                        color: "#CCE95420"
                        clip: true

                        Column {
                            anchors.fill: parent
                            anchors.margins: units.gu(0.4)
                            spacing: units.gu(0.1)

                            Label {
                                width: parent.width
                                elide: Text.ElideRight
                                color: "#FFFFFF"
                                font.pixelSize: units.gu(1.2)
                                text: model.label
                            }
                            Label {
                                width: parent.width
                                elide: Text.ElideRight
                                visible: parent.height > units.gu(3)
                                color: "#FFFFFF"
                                opacity: 0.8
                                font.pixelSize: units.gu(1)
                                text: model.timeText
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: calendarPage.openEvent(model.sourceIndex)
                        }
                    }
                }
            }
        }
    }

    // --- day view ----------------------------------------------------------

    ListView {
        id: dayView
        anchors.top: statusLabel.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: viewMode === 0
        clip: true
        model: dayModel

        delegate: Rectangle {
            width: dayView.width
            height: units.gu(6)
            color: "transparent"

            Rectangle {
                width: units.gu(0.3)
                height: parent.height
                color: "#E95420"
            }
            Label {
                anchors.left: parent.left
                anchors.leftMargin: units.gu(1)
                anchors.verticalCenter: parent.verticalCenter
                width: units.gu(10)
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                color: "#AEA79F"
                text: allDay ? i18n.tr("All day")
                             : Qt.formatTime(new Date(start))
                               + " – " + Qt.formatTime(new Date(end))
            }
            Column {
                anchors.left: parent.left
                anchors.leftMargin: units.gu(11.5)
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                Label {
                    width: parent.width
                    elide: Text.ElideRight
                    color: launchermodular.settings.textColor
                    text: summary
                }
                Label {
                    width: parent.width
                    elide: Text.ElideRight
                    fontSize: "x-small"
                    color: "#AEA79F"
                    visible: text.length > 0
                    text: location
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: calendarPage.openEvent(sourceIndex)
            }
        }
    }

    // Empty day: a blank area looked like the calendar had vanished.
    Label {
        anchors.top: statusLabel.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        visible: calendarPage.viewMode === 0 && dayView.count === 0
        text: i18n.tr("No events for this day")
        color: "#AEA79F"
        wrapMode: Text.WordWrap
        z: 1
    }

    // --- year view ---------------------------------------------------------

    Grid {
        id: yearView
        anchors.top: statusLabel.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: viewMode === 3
        columns: 3
        spacing: units.gu(0.5)

        Repeater {
            model: 12
            Column {
                width: (yearView.width - units.gu(1)) / 3
                spacing: units.gu(0.2)

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    fontSize: "x-small"
                    color: launchermodular.settings.textColor
                    text: Qt.formatDate(new Date(calendarPage.currentDate.getFullYear(), index, 1), "MMM")
                }
                Grid {
                    columns: 7
                    Repeater {
                        model: calendarPage.monthCells(new Date(calendarPage.currentDate.getFullYear(), index, 1))
                        Rectangle {
                            width: units.gu(1.4)
                            height: units.gu(1.4)
                            color: calendarPage.eventsForDay(modelData.day).length > 0 ? "#E95420" : "transparent"
                            border.color: modelData.inMonth ? "#44ffffff" : "transparent"
                            border.width: 1
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    calendarPage.currentDate = modelData.day
                                    calendarPage.viewMode = 2
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- event dialog ------------------------------------------------------

    Component {
        id: eventDialog
        Dialog {
            id: eventDialogItem
            title: calendarPage.editingIndex >= 0 ? i18n.tr("Edit event") : i18n.tr("New event")
            // A press outside the dialog dismisses it, like Cancel.
            __closeOnDismissAreaPress: true

            // The dialog holds many fields: without a bounded, scrollable
            // area, the last rows (All day) are cut on a phone screen.
            Flickable {
                width: parent.width
                height: units.gu(36)
                contentHeight: fieldsColumn.height
                clip: true

                Column {
                    id: fieldsColumn
                    width: parent.width
                    spacing: units.gu(0.6)

                    QControls.TextField {
                        id: summaryField
                        width: parent.width
                        placeholderText: i18n.tr("Title")
                        text: calendarPage.eventSummary
                        onTextChanged: calendarPage.eventSummary = text
                    }
                    QControls.TextField {
                        id: locationField
                        width: parent.width
                        placeholderText: i18n.tr("Location")
                        text: calendarPage.eventLocation
                        onTextChanged: calendarPage.eventLocation = text
                    }
                    QControls.TextArea {
                        id: descriptionField
                        width: parent.width
                        height: units.gu(8)
                        placeholderText: i18n.tr("Description")
                        text: calendarPage.eventDescription
                        onTextChanged: calendarPage.eventDescription = text
                    }
                    Row {
                        width: parent.width
                        spacing: units.gu(0.5)
                        // The date is shown in the user's locale and picked in
                        // a calendar: typing an ISO date was both unreadable
                        // and error-prone.
                        Button {
                            width: units.gu(12)
                            text: calendarPage.displayDate(calendarPage.eventStartDate)
                            onClicked: calendarPage.openDatePicker("start")
                        }
                        QControls.TextField {
                            width: units.gu(7)
                            placeholderText: i18n.tr("Time")
                            text: calendarPage.eventStartTime
                            enabled: !calendarPage.eventAllDay
                            onTextChanged: calendarPage.eventStartTime = text
                            onAccepted: calendarPage.ensureEndAfterStart()
                            onActiveFocusChanged: {
                                if (!activeFocus)
                                    calendarPage.ensureEndAfterStart()
                            }
                        }
                    }
                    Row {
                        width: parent.width
                        spacing: units.gu(0.5)
                        Button {
                            width: units.gu(12)
                            text: calendarPage.displayDate(calendarPage.eventEndDate)
                            onClicked: calendarPage.openDatePicker("end")
                        }
                        QControls.TextField {
                            width: units.gu(7)
                            placeholderText: i18n.tr("Time")
                            text: calendarPage.eventEndTime
                            enabled: !calendarPage.eventAllDay
                            onTextChanged: calendarPage.eventEndTime = text
                            onAccepted: calendarPage.ensureEndAfterStart()
                            onActiveFocusChanged: {
                                if (!activeFocus)
                                    calendarPage.ensureEndAfterStart()
                            }
                        }
                    }
                    // Visible again: it was the row cut by the dialog height.
                    Row {
                        width: parent.width
                        height: units.gu(4)
                        spacing: units.gu(1)
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: i18n.tr("All day")
                            // The dialog has the light Lomiri surface: the
                            // launcher text colour would be white on white.
                            color: Theme.palette.normal.backgroundText
                        }
                        QControls.Switch {
                            anchors.verticalCenter: parent.verticalCenter
                            checked: calendarPage.eventAllDay
                            onClicked: {
                                calendarPage.eventAllDay = checked
                                calendarPage.applyAllDay()
                            }
                        }
                    }
                    Label {
                        id: dialogError
                        width: parent.width
                        wrapMode: Text.WordWrap
                        color: "#ED3146"
                        text: calendarPage.eventError
                    }
                }
            }
            Row {
                spacing: units.gu(1)
                Button {
                    text: i18n.tr("Save")
                    onClicked: calendarPage.saveEvent()
                }
                Button {
                    text: i18n.tr("Delete")
                    visible: calendarPage.editingIndex >= 0
                    onClicked: PopupUtils.open(confirmDelete)
                }
                Button {
                    text: i18n.tr("Cancel")
                    onClicked: PopupUtils.close(eventDialogItem)
                }
            }
        }
    }

    // Calendar shown when the calendar button of a date field is pressed.
    // It reuses the month grid of the page; clicking a day closes it.
    Component {
        id: datePickerDialog
        Dialog {
            id: datePickerDialogItem
            title: i18n.tr("Choose a date")
            __closeOnDismissAreaPress: true

            Column {
                spacing: units.gu(1)

                Row {
                    width: parent.width
                    spacing: units.gu(1)

                    Icon {
                        height: units.gu(2.5)
                        width: height
                        name: "go-previous"
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: units.gu(-0.5)
                            onClicked: calendarPage.shiftPickerMonth(-1)
                        }
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDate(calendarPage.datePickerMonth, "MMMM yyyy")
                        color: Theme.palette.normal.backgroundText
                        font.bold: true
                    }
                    Icon {
                        height: units.gu(2.5)
                        width: height
                        name: "go-next"
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: units.gu(-0.5)
                            onClicked: calendarPage.shiftPickerMonth(1)
                        }
                    }
                }

                Grid {
                    columns: 7
                    Repeater {
                        model: calendarPage.monthCells(calendarPage.datePickerMonth)
                        Rectangle {
                            width: units.gu(4.6)
                            height: units.gu(4.6)
                            color: calendarPage.sameDay(modelData.day, calendarPage.datePickerSelected)
                                   ? "#E95420"
                                   : (modelData.inMonth ? "#22ffffff" : "transparent")
                            border.color: "#33ffffff"
                            border.width: 1

                            Label {
                                anchors.centerIn: parent
                                text: modelData.day.getDate()
                                color: Theme.palette.normal.backgroundText
                                opacity: modelData.inMonth ? 1 : 0.4
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: calendarPage.pickDate(modelData.day)
                            }
                        }
                    }
                }

                Button {
                    text: i18n.tr("Cancel")
                    onClicked: PopupUtils.close(datePickerDialogItem)
                }
            }
        }
    }

    Component {
        id: confirmDelete
        Dialog {
            id: confirmDeleteItem
            title: i18n.tr("Delete event")
            text: i18n.tr("The event will be removed from Nextcloud. Continue?")
            Button {
                text: i18n.tr("Delete")
                onClicked: {
                    NextcloudCalendarModel.deleteEvent(calendarPage.editingIndex, function (success, code) {
                        if (!success) {
                            calendarPage.eventError = i18n.tr("The server refused the deletion (HTTP %1)").arg(code)
                            PopupUtils.close(confirmDeleteItem)
                            return
                        }
                        PopupUtils.close(confirmDeleteItem)
                        if (eventDialogObject) PopupUtils.close(eventDialogObject)
                        NextcloudCalendarModel.refresh(60, 180)
                    })
                }
            }
            Button {
                text: i18n.tr("Cancel")
                onClicked: PopupUtils.close(confirmDeleteItem)
            }
        }
    }
}
