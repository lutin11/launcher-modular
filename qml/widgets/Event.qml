import QtQuick 2.4
import Ubuntu.Components 1.3
import Ubuntu.Components.ListItems 1.3
import QtOrganizer 5.0

Item {
    id: widgetEvent
    width: listColumn.width/2
    height: event.height+emptyLabel.height
   
    function getTodayBaseLine() {
        var lowerToday = new Date()
        lowerToday.setHours(0, 1, 0, 0)
        return lowerToday
    }

    OrganizerModel {
        id: organizerModel

        function updateCalendarModel() {
            update()
        }

        startPeriod: {
            return getTodayBaseLine();
        }

        endPeriod: {
            var endPeriodDate = getTodayBaseLine();
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

        onModelChanged: {
            widgetEventModel.clear();
            var count = organizerModel.itemCount
            for ( var i = 0; i < count; i ++ ) {
                var item = organizerModel.items[i];
                var today = getTodayBaseLine();
                var limitDown = item.startDateTime >= today
                if(item.itemType !== 505 && limitDown){
                    if(widgetEventModel.count < launchermodular.settings.limiteItemWidgetEvent){
                      widgetEventModel.append( {"item": item })
                    }
                }
            }
        }

        manager: "eds"
    }

    function updateModel() {
        organizerModel.updateCalendarModel()
    }

    property var updateModelFunction: updateModel

    Connections {
        target: launchermodular.settings
        onLimiteItemWidgetEventChanged: {
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
            visible: listEvent.count == 0
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
                        var callendarEvent = item.detail(Detail.EventTime)
                        var eventStartTime = callendarEvent.startDateTime;
                        if(index != 0){
                            var prevEventeventStartTime = widgetEventModel.get(index-1).item.detail(Detail.EventTime).startDateTime;
                            if(Qt.formatDateTime(eventStartTime, "MMM d" ) != Qt.formatDateTime(prevEventeventStartTime, "MMM d" )){
                              return Qt.formatDateTime(eventStartTime, "MMM d" )
                            } else {
                              return ""
                            }
                        } else {
                            return Qt.formatDateTime(eventStartTime, "MMM d" )
                        }
                    }
                    horizontalAlignment: Text.AlignRight;
                    width: units.gu(4);
                    color: launchermodular.settings.textColor;
                    font.pointSize: units.gu(1.2);
                }
                Rectangle {
                    height: parent.height;
                    width: units.gu(0.1);
                    color: "#E95420";
                }

                Column{
                    Text {
                        text: item.displayLabel;
                        wrapMode: Text.WordWrap;
                        elide: Text.ElideRight;
                        width: event.width-units.gu(4);
                        color: launchermodular.settings.textColor;
                        font.pointSize: units.gu(1.2);
                    }
                    Text {
                        text: {
                            var callendarEvent = item.detail(Detail.EventTime)
                            var eventStartTime = callendarEvent.startDateTime;
                            return Qt.formatDateTime(eventStartTime, "hh:mm" )+" "+item.description
                        }
                        elide: Text.ElideRight;
                        maximumLineCount: 1;
                        width: event.width-units.gu(4);
                        color: "#AEA79F"; font.pointSize: units.gu(1);
                    }
                }
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        onClicked:{clickTimer.start();}
        onPressAndHold: pageStack.push(Qt.resolvedUrl("event/Settings.qml"))
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
