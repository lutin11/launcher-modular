import QtQuick 2.4
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.0
import "../components"
import Qt.labs.settings 1.0
import Ubuntu.History 0.1
import Ubuntu.Contacts 0.1
import ContactHelper 1.0

Item {
    id: widgetLastMessage
    width: listColumn.width/2
    height: message.height + (listMessage.count > 0 ? listMessage.contentHeight : emptyLabel.height) + units.gu(1)
        
    property ListModel messageList:  ListModel {}

    ContactHelper {
        id: contactHelper
    }

    function fetchContactById(contactId) {
        var contactFullName = "";
        if (contactId) {
            let contact = contactHelper.getContactById(contactId);
            if (contact) {
                if (contact["firstName"]) {
                contactFullName  += contact["firstName"];
                }
                if (contact["lastName"]) {
                    contactFullName += " " + contact["lastName"];
                }
            } else {
                console.log("No contact found for ID:", contactId);
            }
        }
        return contactFullName;
    }

    function updateFilteredModel() {
        messageList.clear(); // Clear the existing list
        var numberOfVisibleItems = launchermodular.settings.numberOfMessageWidget;
        var count = Math.min(historyMessageModel.count, numberOfVisibleItems);

        var visibleItemCount = 0; // Keep track of added items

        for (let i = 0; i < historyMessageModel.count && visibleItemCount < numberOfVisibleItems; i++) {
            var event = historyMessageModel.get(i);

            // Skip events where senderId is "self"
            if (launchermodular.settings.widgetMessageFilterOnReceivedMessages && event.eventSenderId === "self") {
                continue;
            }

            var participants = event.participants;

            // Fetch contactId and full name
            let contactId = event.properties.participants[0] ? event.properties.participants[0].contactId : ""; // Use optional chaining to avoid errors
            var contactFullName = fetchContactById(contactId);
            var participantsString = participants.toString();

            // Append the filtered event to the messageList
            messageList.append({
                participants: participantsString,
                contactFullName: contactFullName,
                timestamp: event.timestamp,
                eventTextMessage: event.eventTextMessage
            });

            visibleItemCount++;
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

        Rectangle {
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
                text: listMessage.count > 1 ? i18n.tr("Last Messages") : i18n.tr("Last Message")
                color: launchermodular.settings.textColor
            }
        }

        Component.onCompleted: {
            updateFilteredModel();
        }

        // Watch for changes to the parameters
        Connections {
            target: launchermodular.settings
            onNumberOfMessageWidgetChanged: {
                widgetLastMessage.updateFilteredModelFunction();
            }
            onWidgetMessageSummaryChanged: {
                widgetLastMessage.updateFilteredModelFunction();
            }
            onWidgetMessageFilterOnReceivedMessagesChanged: {
                widgetLastMessage.updateFilteredModelFunction();
            }
        }

        HistoryThreadModel {
            id: historyMessageModel
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
            model: messageList
            width: parent.width
            interactive: false
            spacing: 0
            clip: true

            delegate: Item {
                id: listMessageItem
                width:parent.width;
                height: units.gu(3)

                MouseArea {
                    id: itemMouseArea
                    anchors.fill: parent
                    onClicked: {
                        if ("default" == launchermodular.settings.widgetMessageClick) {
                            Qt.openUrlExternally("application:///messaging-app.desktop");
                        }
                        if ("message" == launchermodular.settings.widgetMessageClick) {
                            Qt.openUrlExternally("message:///" + participants);
                        }
                    }
                    onPressAndHold: pageStack.push(Qt.resolvedUrl("lastmessage/Settings.qml"))
                }
                Column {
                    id: visibleContent
                    anchors.fill: parent
                    width:parent.width
                    spacing: 0

                    Text {
                        text: contactFullName.length > 0 ? contactFullName : participants
                        color: launchermodular.settings.textColor
                        font.pointSize: units.gu(1.2)
                    }
                    Text {
                        text: timestamp.toLocaleString(Qt.locale(), Locale.ShortFormat)
                        color: "#AEA79F"
                        font.pointSize: units.gu(1)
                    }
                    Text {
                        text: eventTextMessage
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        width: message.width
                        color: launchermodular.settings.textColor
                        font.pointSize: units.gu(1.1)
                        visible: launchermodular.settings.widgetMessageSummary
                    }
                }
                Component.onCompleted: {
                    if (visibleContent.height+units.gu(3) !== units.gu(3)) {
                        height = visibleContent.height+units.gu(3);
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
            visible: listMessage.count == 0
            height: units.gu(3)
            text: i18n.tr("No recent messages")
            color: launchermodular.settings.textColor
        }
    }
}