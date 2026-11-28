import QtQuick 2.12
import Lomiri.Components 1.3
import Lomiri.Components.ListItems 1.3
import QtOrganizer 5.0
import Platform 1.0
import "../pages/nextcloudcalendar"

Item {
    id: widgetEvent
    width: listColumn.width/2
    height: event.height+emptyLabel.height
   
    function getTodayBaseLine() {
        var lowerToday = new Date()
        lowerToday.setHours(0, 1, 0, 0)
        return lowerToday
    }

    // Empty table is for all calendar selected
    CollectionFilter {
        id: calendarCollectionFilter
        ids: launchermodular.settings.selectedCalendarIds
    }

    // The system agenda needs a QtOrganizer provider. Without one (stock
    // Debian/Ubuntu/Mint ship only the QML module) the model is not created at
    // all: the widget still lists the Nextcloud events.
    Loader {
        id: organizerLoader
        active: Platform.hasCalendarFeature
        sourceComponent: Component {
            OrganizerModel {
                id: systemOrganizerModel

                function updateCalendarModel() {
                    update()
                }

                startPeriod: {
                    return widgetEvent.getTodayBaseLine();
                }

                endPeriod: {
                    var endPeriodDate = widgetEvent.getTodayBaseLine();
                    endPeriodDate.setDate(endPeriodDate.getDate() + launchermodular.settings.limiteDaysWidgetEvent)
                    return endPeriodDate
                }

                sortOrders: [
                    SortOrder{
                        id: sortOrder
                        blankPolicy: SortOrder.BlanksFirst
                        detail: Detail.EventTime
                        field: EventTime.FieldStartDateTime
                        direction: Qt.AscendingOrder
                    }
                ]

                filter: (launchermodular.settings.selectedCalendarIds && launchermodular.settings.selectedCalendarIds.length > 0)
                    ? calendarCollectionFilter
                    : null

                // Only load from backend details from selected calendar
                fetchHint: FetchHint {
                    detailTypesHint: [Detail.EventTime, Detail.DisplayLabel, Detail.Description, Detail.Guid, Detail.ItemType]
                    optimizationHints: FetchHint.NoBinaryBlobs
                }

                onModelChanged: Qt.callLater(widgetEvent.rebuildWidgetEventModel)

                // Preferred provider of the machine; "eds" is the Ubuntu Touch
                // one.
                manager: Platform.preferredOrganizerManager.length > 0
                         ? Platform.preferredOrganizerManager : "eds"
            }
        }
    }

    readonly property var organizerModel: organizerLoader.item

    // The widget shows the events of the system agenda and those of the
    // Nextcloud calendar, merged and sorted. Roles: label, description,
    // start (Date), allDay, source.
    function rebuildWidgetEventModel() {
        widgetEventModel.clear()
        var merged = []
        var today = getTodayBaseLine()
        var limit = launchermodular.settings.limiteItemWidgetEvent
        var items = organizerModel ? organizerModel.items : []
        var count = organizerModel ? organizerModel.itemCount : 0
        for (var index = 0; index < count; index++) {
            var item = items[index]
            if (item.itemType === 505)
                continue
            var time = item.detail(Detail.EventTime)
            if (!time || time.startDateTime < today)
                continue
            merged.push({
                label: item.displayLabel,
                description: item.description || "",
                start: time.startDateTime,
                allDay: time.allDay,
                source: "system"
            })
        }
        if (NextcloudCalendarModel.configured) {
            var remote = NextcloudCalendarModel.upcoming(launchermodular.settings.limiteDaysWidgetEvent, today)
            for (var remoteIndex = 0; remoteIndex < remote.length; remoteIndex++) {
                merged.push({
                    label: remote[remoteIndex].summary,
                    description: remote[remoteIndex].description || "",
                    start: new Date(remote[remoteIndex].start),
                    allDay: remote[remoteIndex].allDay,
                    source: "nextcloud"
                })
            }
        }
        merged.sort(function (first, second) { return first.start.getTime() - second.start.getTime() })
        for (var mergedIndex = 0; mergedIndex < merged.length && widgetEventModel.count < limit; mergedIndex++)
            widgetEventModel.append(merged[mergedIndex])
    }

    // One configured account can expose several calendars: the model works
    // with one entry per calendar.
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

    // Accounts of all the calendar pages, so the widget shows their events
    // even when the calendar page has never been opened.
    function loadNextcloudAccounts() {
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
        var list = expandAccounts(stored)
        if (list.length > 0) {
            NextcloudCalendarModel.configureAccounts(list)
            NextcloudCalendarModel.refresh(60, 180)
        }
    }

    Component.onCompleted: loadNextcloudAccounts()

    Connections {
        target: NextcloudCalendarModel
        function onUpdated() { Qt.callLater(rebuildWidgetEventModel) }
    }

    function updateModel() {
        if (organizerModel)
            organizerModel.updateCalendarModel()
        else
            rebuildWidgetEventModel()
    }

    property var updateModelFunction: updateModel

    Connections {
        target: launchermodular.settings
        function onLimiteItemWidgetEventChanged() {
             if (DEBUG_MODE) console.log("Change detected")
             widgetEvent.updateModelFunction();
        }
    }
        
    Rectangle {
        id: event
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: rectEvent.height+listEvent.height
        color: "transparent"

        Rectangle{
            id: rectEvent
            height: units.gu(2.5)
            color: "transparent"
            Icon {
               id: iconEvent
                width: units.gu(2)
                height: units.gu(2)
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                name: "event"
                color: launchermodular.settings.textColor
            }
            Label {
                id: titleEvent
                anchors.left: iconEvent.right
                anchors.leftMargin: units.gu(1)
                text: i18n.tr("Events")
                color: launchermodular.settings.textColor
            }
        }

        ListModel {
            id: widgetEventModel
        }

        Label {
            id: emptyLabel
            fontSize: "small"
            anchors.top: rectEvent.bottom
            visible: listEvent.count === 0
            text: i18n.tr("No events")
            color: launchermodular.settings.textColor
        }

        ListView {
            id: listEvent
            anchors.top: rectEvent.bottom
            height: contentHeight
            model: widgetEventModel
            interactive: false
            delegate: Row {
                spacing: units.gu(0.7)
                Text {
                    text: {
                        var current = new Date(model.start)
                        if (index !== 0) {
                            var previous = widgetEventModel.get(index - 1)
                            if (previous && Qt.formatDateTime(current, "MMM d")
                                    === Qt.formatDateTime(new Date(previous.start), "MMM d"))
                                return ""
                        }
                        return Qt.formatDateTime(current, "MMM d")
                    }
                    horizontalAlignment: Text.AlignRight
                    width: units.gu(4)
                    color: launchermodular.settings.textColor
                    font.pointSize: units.gu(1.2)
                }
                Rectangle {
                    height: parent.height
                    width: units.gu(0.1)
                    color: "#E95420"
                }

                Column {
                    Text {
                        text: model.label
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                        width: event.width - units.gu(4)
                        color: launchermodular.settings.textColor
                        font.pointSize: units.gu(1.2)
                    }
                    Text {
                        text: (model.allDay ? i18n.tr("All day")
                                            : Qt.formatDateTime(new Date(model.start), "hh:mm"))
                              + (model.description ? " " + model.description : "")
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        width: event.width - units.gu(4)
                        color: "#AEA79F"
                        font.pointSize: units.gu(1)
                    }
                }
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        onClicked:{clickTimer.start();}
        onPressAndHold: {
            // The settings page lists the system calendars: it is only useful
            // when a QtOrganizer provider is available.
            if (Platform.hasCalendarFeature)
                pageStack.push(Qt.resolvedUrl("event/Settings.qml"))
        }
        onDoubleClicked: {clickTimer.stop(); updateModel();}
    }

    // Timer to delay the single-click action
    Timer {
        id: clickTimer
        interval: 250  // Adjust delay (in milliseconds) as needed
        repeat: false
        onTriggered: {
            // Single-click action only happens after the timer completes
            Qt.openUrlExternally("application:///calendar.ubports_calendar.desktop")
        }
    }
}
