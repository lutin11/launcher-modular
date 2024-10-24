import QtQuick 2.12
import Lomiri.Components 1.3
import QtOrganizer 5.0


Item {
    id: calendar

    property variant datenow: new Date()

    function updateFilteredModel() {
        var lowerToday = new Date()
        lowerToday.setHours(0, 1, 0, 0)
        return lowerToday
    }
    property var updateFilteredModelFunction: updateFilteredModel

    Timer {
        interval: 120000 // update clock every second
        running: true
        repeat: true
        onTriggered: {
            calendar.datenow = new Date()
        }
    }

    OrganizerModel {
        id: organizerModel

        startPeriod: {
            return updateFilteredModelFunction();
        }

        endPeriod: {
            var endPeriodDate = updateFilteredModelFunction();
            endPeriodDate.setDate(endPeriodDate.getDate() + launchermodular.settings.limiteDaysCalendar);
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

        onExportCompleted: {
            console.log("onExportCompleted")
        }

        onImportCompleted: {
            console.log("onImportCompleted")
        }

        onItemsFetched: {
            console.log("onItemsFetched")
        }

        onModelChanged: {
            calandarEventModel.clear();
            var count = organizerModel.itemCount
            for ( var i = 0; i < count; i ++ ) {
                var item = organizerModel.items[i];
                var today = updateFilteredModelFunction();
                var limitDown = item.startDateTime >= today
                if(item.itemType !== 505 && limitDown && calandarEventModel.count < launchermodular.settings.limiteDaysCalendar){
                    calandarEventModel.append( {"item": item })
                }
            }
        }
        onDataChanged: {
            console.log("onDataChanged")
        }
        manager: "eds"
    }

    ListModel {
        id: calandarEventModel
    }

    ListView {
        id: listCalendar
        anchors.fill: parent
        anchors.left: parent.left
        anchors.leftMargin: units.gu(2)
        width: parent.width
        height: contentHeight
        model: calandarEventModel

        header: Item {
            id: textCalendar
            height: units.gu(6)

            Icon {
               id: iconCalendar
                width: units.gu(2)
                height: units.gu(2)
                name: "event"
                color: launchermodular.settings.textColor
                anchors.verticalCenter: parent.verticalCenter
            }
            Label {
                id: titleCalendar
                anchors.left: iconCalendar.right
                anchors.leftMargin: units.gu(1)
                text: i18n.tr("Agenda")
                color: launchermodular.settings.textColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        delegate: ListItem {
            height: layout.height + (divider.visible ? divider.height : 0)
            divider.visible: false
            ListItemLayout {
                id: layout
                title.text: item.displayLabel
                title.color: "#FFFFFF"
                subtitle.text: {
                    var evt_time = item.detail(Detail.EventTime)
                    var starttime = evt_time.startDateTime;
                    var endtime = evt_time.endDateTime;

                    return starttime.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)+" - "+endtime.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
                }
                subtitle.color: "#AEA79F"
                summary.text: item.description
                summary.color: "#AEA79F"
                Column {
                    id: timeEvent
                    SlotsLayout.position: SlotsLayout.Leading
                    Text{
                        text: {
                            var evt_time = item.detail(Detail.EventTime)
                            var starttime = evt_time.startDateTime;
                            return Qt.formatDateTime(starttime, "d" )
                        }
                        font.pointSize: units.gu(2.2)
                        font.bold: true
                        color: "#ffffff"
                    }
                    Text{
                        text: {
                          var evt_time = item.detail(Detail.EventTime)
                          var starttime = evt_time.startDateTime;
                          return Qt.formatDateTime(starttime, "MMM" )
                        }
                        color: "#ffffff"
                    }
                }
                Item {
                    id: slot
                    width: secondLabel.width
                    anchors.right: parent.right
                    anchors.top: timeEvent.top
                    anchors.topMargin: units.gu(1)
                    Label {
                        id: secondLabel
                        text: item.location
                        color: "#AEA79F"
                        fontSize: "small"
                        y: layout.mainSlot.y + layout.summary.y
                           + layout.summary.baselineOffset - baselineOffset
                    }
                }

            }
             /*
            MouseArea {
                anchors.fill: parent
                onClicked:{
                    Qt.openUrlExternally("calendar://eventid="+item.itemId)
                   // onClicked:Qt.openUrlExternally("application:///calendar.ubports_calendar.desktop")
                }
            }
            */

        }

    }

}
