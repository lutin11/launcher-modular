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

    readonly property var weekDayNames: [
        i18n.tr("Mon"), i18n.tr("Tue"), i18n.tr("Wed"), i18n.tr("Thu"),
        i18n.tr("Fri"), i18n.tr("Sat"), i18n.tr("Sun")
    ]

    Component.onCompleted: {
        loadAccounts()
        refreshDayModel()
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
    function loadAccounts() {
        var list = []
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
                try { list = list.concat(JSON.parse(raw)) } catch (error) { }
            } else if ((config.nextcloudAccounts && config.nextcloudAccounts.length > 0)
                       || (data.nextcloudAccounts && data.nextcloudAccounts.length > 0)) {
                var stored = (config.nextcloudAccounts && config.nextcloudAccounts.length > 0)
                        ? config.nextcloudAccounts : data.nextcloudAccounts
                for (var accountIndex = 0; accountIndex < stored.length; accountIndex++)
                    list.push(stored[accountIndex])
            } else if ((config.nextcloudUrl || data.nextcloudUrl)
                       && (config.nextcloudUser || data.nextcloudUser)
                       && (config.nextcloudPassword || data.nextcloudPassword)) {
                list.push({ url: config.nextcloudUrl || data.nextcloudUrl,
                            user: config.nextcloudUser || data.nextcloudUser,
                            password: config.nextcloudPassword || data.nextcloudPassword,
                            href: config.nextcloudCalendarHref || data.nextcloudCalendarHref || "",
                            name: "" })
            }
        }
        if (list.length === 0 && launchermodular.settings.nextcloudAccountsJson.length > 0) {
            try { list = JSON.parse(launchermodular.settings.nextcloudAccountsJson) } catch (error) { list = [] }
        }
        if (list.length === 0 && launchermodular.settings.nextcloudUrl
                && launchermodular.settings.nextcloudUser && launchermodular.settings.nextcloudPassword) {
            list.push({ url: launchermodular.settings.nextcloudUrl,
                        user: launchermodular.settings.nextcloudUser,
                        password: launchermodular.settings.nextcloudPassword,
                        href: launchermodular.settings.nextcloudCalendarHref || "", name: "" })
        }
        accounts = list
        if (targetAccount >= accounts.length)
            targetAccount = 0
        NextcloudCalendarModel.configureAccounts(accounts)
    }

    onCurrentDateChanged: refreshDayModel()
    onViewModeChanged: if (viewMode === 0) refreshDayModel()

    Connections {
        target: NextcloudCalendarModel
        onUpdated: calendarPage.refreshDayModel()
    }


    // --- dates -------------------------------------------------------------

    function startOfDay(date) {
        var copy = new Date(date)
        copy.setHours(0, 0, 0, 0)
        return copy
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
            if (event.start >= from && event.start < to)
                result.push({ index: index, event: event })
        }
        return result
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
            return Qt.formatDate(currentDate, "dddd d MMMM yyyy")
        if (viewMode === 1)
            return Qt.formatDate(currentDate, "MMMM yyyy")
        if (viewMode === 2)
            return Qt.formatDate(currentDate, "MMMM yyyy")
        return currentDate.getFullYear().toString()
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

    function formatTimeInput(date) {
        return Qt.formatTime(date, "HH:mm")
    }

    function openNewEvent(day) {
        var start = startOfDay(day || currentDate)
        start.setHours(9, 0, 0, 0)
        var end = new Date(start.getTime() + 3600000)
        editingIndex = -1
        eventSummary = ""
        eventLocation = ""
        eventDescription = ""
        eventStartDate = formatDateInput(start)
        eventStartTime = formatTimeInput(start)
        eventEndDate = formatDateInput(end)
        eventEndTime = formatTimeInput(end)
        eventAllDay = false
        PopupUtils.open(eventDialog)
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
        PopupUtils.open(eventDialog)
    }

    function parseDateTime(dateText, timeText) {
        var parsed = new Date(dateText + "T" + (eventAllDay ? "00:00" : timeText) + ":00")
        return isNaN(parsed.getTime()) ? null : parsed
    }

    function saveEvent() {
        var start = parseDateTime(eventStartDate, eventStartTime)
        var end = parseDateTime(eventEndDate, eventEndTime)
        if (!start || !end) {
            dialogError.text = i18n.tr("Invalid date or time")
            return
        }
        if (end.getTime() <= start.getTime()) {
            dialogError.text = i18n.tr("The end must be after the start")
            return
        }
        if (eventSummary.trim().length === 0) {
            dialogError.text = i18n.tr("The title is required")
            return
        }
        dialogError.text = ""
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
                dialogError.text = i18n.tr("The server refused the change (HTTP %1)").arg(code)
                return
            }
            PopupUtils.close(eventDialog)
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
            width: toolbar.width - units.gu(16)
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
                        onUpdated: monthCell.loadCellEvents()
                    }

                    Rectangle {
                        width: parent.width
                        height: parent.height
                        color: calendarPage.sameDay(modelData.day, new Date()) ? "#33E95420" : "transparent"
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

    ListView {
        id: weekView
        anchors.top: statusLabel.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: viewMode === 1
        clip: true
        model: 7

        delegate: Column {
            id: weekDay
            width: weekView.width
            spacing: units.gu(0.3)

            property date day: calendarPage.addDays(calendarPage.startOfDay(calendarPage.currentDate), index)

            // A ListModel per day: a Repeater fed by a JS array rebuilt by a
            // function loops on its "model" property.
            ListModel { id: weekDayEvents }

            function loadEvents() {
                weekDayEvents.clear()
                var events = calendarPage.eventsForDay(weekDay.day)
                for (var eventIndex = 0; eventIndex < events.length; eventIndex++) {
                    weekDayEvents.append({
                        summary: events[eventIndex].event.summary,
                        start: events[eventIndex].event.start,
                        allDay: events[eventIndex].event.allDay,
                        sourceIndex: events[eventIndex].index
                    })
                }
            }

            Component.onCompleted: loadEvents()
            onDayChanged: loadEvents()

            Connections {
                target: NextcloudCalendarModel
                onUpdated: weekDay.loadEvents()
            }

            Label {
                text: Qt.formatDate(weekDay.day, "dddd d MMMM")
                color: launchermodular.settings.textColor
                fontSize: "small"
            }
            Repeater {
                model: weekDayEvents
                Item {
                    width: weekView.width
                    height: weekRow.height
                    Row {
                        id: weekRow
                        width: parent.width
                        spacing: units.gu(0.5)
                        Label {
                            width: units.gu(5)
                            fontSize: "x-small"
                            color: "#AEA79F"
                            text: allDay ? i18n.tr("All day")
                                         : Qt.formatTime(new Date(start), "HH:mm")
                        }
                        Label {
                            width: weekView.width - units.gu(6)
                            elide: Text.ElideRight
                            fontSize: "x-small"
                            color: launchermodular.settings.textColor
                            text: summary
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: calendarPage.openEvent(sourceIndex)
                    }
                }
            }
            Label {
                visible: weekDayEvents.count === 0
                text: i18n.tr("No event")
                fontSize: "x-small"
                color: "#AEA79F"
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
                             : Qt.formatTime(new Date(start), "HH:mm")
                               + " – " + Qt.formatTime(new Date(end), "HH:mm")
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
                        QControls.TextField {
                            width: units.gu(12)
                            placeholderText: i18n.tr("Start date")
                            text: calendarPage.eventStartDate
                            onTextChanged: calendarPage.eventStartDate = text
                        }
                        QControls.TextField {
                            width: units.gu(7)
                            placeholderText: i18n.tr("Time")
                            text: calendarPage.eventStartTime
                            enabled: !calendarPage.eventAllDay
                            onTextChanged: calendarPage.eventStartTime = text
                        }
                    }
                    Row {
                        width: parent.width
                        spacing: units.gu(0.5)
                        QControls.TextField {
                            width: units.gu(12)
                            placeholderText: i18n.tr("End date")
                            text: calendarPage.eventEndDate
                            onTextChanged: calendarPage.eventEndDate = text
                        }
                        QControls.TextField {
                            width: units.gu(7)
                            placeholderText: i18n.tr("Time")
                            text: calendarPage.eventEndTime
                            enabled: !calendarPage.eventAllDay
                            onTextChanged: calendarPage.eventEndTime = text
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
                            onCheckedChanged: calendarPage.eventAllDay = checked
                        }
                    }
                    Label {
                        id: dialogError
                        width: parent.width
                        wrapMode: Text.WordWrap
                        color: "#ED3146"
                        text: ""
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
                            dialogError.text = i18n.tr("The server refused the deletion (HTTP %1)").arg(code)
                            PopupUtils.close(confirmDeleteItem)
                            return
                        }
                        PopupUtils.close(confirmDeleteItem)
                        PopupUtils.close(eventDialog)
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
