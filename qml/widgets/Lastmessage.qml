import QtQuick 2.12
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.0
import "../components"
import Qt.labs.settings 1.0
import Lomiri.History 0.1
import Lomiri.Contacts 0.1

Item {
    id: widgetLastMessage
    width: listColumn.width/2
    height: message.height + (listMessage.count > 0 ? listMessage.contentHeight : emptyLabel.height) + units.gu(1)
        
    property ListModel filteredModel:  ListModel {}

    function updateFilteredModel() {
        filteredModel.clear();
        var numberOfVisibleItems = launchermodular.settings.numberOfMessageWidget;
        var count = Math.min(historyThreadModel.count, numberOfVisibleItems);
        // Get the participants value from the historyThreadModel
        console.log("updateFilteredModel")
        for (var i = 0; i < count; i++) {
            console.log("append eventTextMessage:"+ historyThreadModel.get(i).eventTextMessage)
            console.log("append timestamp:"+ historyThreadModel.get(i).timestamp)
            var participants = historyThreadModel.get(i).participants;
            participants = participants.toString();
            console.log("append participants:"+ participants)

            filteredModel.append({
                eventTextMessage: historyThreadModel.get(i).eventTextMessage,
                timestamp: historyThreadModel.get(i).timestamp,
                participants: participants,  // Now a string
            });
        }
    }

    function updateListViewHeight() {
      // force view to refresh
    }

    property var updateFilteredModelFunction: updateFilteredModel


    Rectangle {
        id: message
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width

        Rectangle{
            id: rectLastMessageTitle
            height: units.gu(2.5)
            color: "transparent"
            Icon {
                id: iconLastMessage
                width: units.gu(2)
                height: units.gu(2)
                name: "message"
                color: launchermodular.settings.textColor
            }
            Label {
                id: titleLastMessage
                anchors.left: iconLastMessage.right
                anchors.leftMargin: units.gu(1)
                text: i18n.tr("Last Message")
                color: launchermodular.settings.textColor
            }
        }

        Component.onCompleted: {
            updateFilteredModel();
        }

        // Watch for changes to the numberOfMessageWidget parameter
        Connections {
            target: launchermodular.settings
            onNumberOfMessageWidgetChanged: {
                widgetLastMessage.updateFilteredModelFunction();
            }
        }

        HistoryThreadModel {
            id: historyThreadModel
            filter: HistoryFilter {}
            sort: HistorySort {
                sortField: "lastEventTimestamp"
                sortOrder: HistorySort.DescendingOrder
            }
        }

        ListView {
            id: listMessage
            anchors.top: rectLastMessageTitle.bottom
            height: contentHeight
            model: filteredModel
            width:parent.width;
            interactive: false
            spacing: 0
            clip: true

            delegate: Item {
                id: listMessageItem
                width:parent.width;
                height: visibleContent.height+units.gu(3)

                MouseArea {
                    id: itemMouseArea
                    anchors.fill: parent
                    onClicked: {
                        if ("default" === launchermodular.settings.widgetMessageClick){Qt.openUrlExternally("application:///messaging-app.desktop")}
                        if ("message" === launchermodular.settings.widgetMessageClick){Qt.openUrlExternally("message:///"+participants)}
                    }
                    onPressAndHold:pageStack.push(Qt.resolvedUrl("lastmessage/Settings.qml"))
                }
                Column {
                    id: visibleContent
                    anchors.fill: parent
                    width:parent.width;
                    spacing: 0

                    Text {
                        text: participants;
                        color: launchermodular.settings.textColor;
                        font.pointSize: units.gu(1.2);
                    }
                    Text {
                        text: timestamp.toLocaleString(Qt.locale(), Locale.ShortFormat);
                        color: "#AEA79F";
                        font.pointSize: units.gu(1);
                    }
                    Text {
                        text: eventTextMessage;
                        elide: Text.ElideRight;
                        maximumLineCount: 1;
                        width: message.width;
                        color: launchermodular.settings.textColor;
                        font.pointSize: units.gu(1.1);
                        visible: launchermodular.settings.widgetMessageSummary;
                    }
                }
            }
            onCountChanged: {
                updateListViewHeight();  // Update height manually when count changes
            }

        }

        Label {
            id: emptyLabel
            fontSize: "small"
            anchors.top: rectLastMessageTitle.bottom
            visible: listMessage.count === 0
            height: listMessage.count === 0 ? units.gu(3) : 0
            text: i18n.tr("No recent messages")
            color: launchermodular.settings.textColor
        }
    }
}
