import QtQuick 2.12
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.0
import "../components"
import Qt.labs.settings 1.0
import Lomiri.History 0.1
import Lomiri.Contacts 0.1
import ContactHelper 1.0

Item {
    id: widgetLastCall
    width: listColumn.width/2
    height: rectLastCallTitle.height + (listCall.count > 0 ? listCall.contentHeight : emptyLabel.height) + units.gu(1)

    property ListModel callList:  ListModel {}

    ContactHelper {
        id: contactHelper
    }

    function fetchContactById(contactId) {
        var contactFullName = "";
        let contact = contactHelper.getContactById(contactId);
        if (contact) {
            contactFullName  = contact["firstName"];
            if (contact.midleName) {
                contactFullName += " " + contact["lastName"];
            }
        } else {
            console.log("No contact found for ID:", contactId);
        }
        return contactFullName;
    }

    function updateFilteredModel() {
        callList.clear();
        var numberOfVisibleItems = launchermodular.settings.numberOfCallWidget;
        var count = Math.min(historyCallModel.count, numberOfVisibleItems);
        for (let i = 0; i < count; i++) {
            // Get the participants value from the historyCallModel
            var event = historyCallModel.get(i);
            let contactId = event.properties.participants[0].contactId;
            var contactFullName = fetchContactById(contactId);
            var participants = event.participants;
            participants = participants.toString();
            callList.append({
                participants: participants,  // Now a string
                contactFullName: contactFullName,
                timestamp: historyCallModel.get(i).timestamp
            });
        }
    }

    function updateListViewHeight() {
      // force view to refresh
    }

    property string callNumber: ""

    property var updateFilteredModelFunction: updateFilteredModel

    Rectangle {
        id: call
        width: parent.width

        Rectangle{
            id: rectLastCallTitle
            height: units.gu(2.5)
            color: "transparent"
            Icon {
               id: iconLastCall
                width: units.gu(2)
                height: units.gu(2)
                name: "call-start"
                color: launchermodular.settings.textColor
            }
            Label {
                id: titleLastCall
                anchors.left: iconLastCall.right
                anchors.leftMargin: units.gu(1)
                text: callList.count > 1 ? i18n.tr("Last Calls") : i18n.tr("Last Call")
                color: launchermodular.settings.textColor
            }
        }

        Component.onCompleted: {
            updateFilteredModel();
        }

        // Watch for changes to the numberOfCallWidget parameter
        Connections {
            target: launchermodular.settings
            onNumberOfCallWidgetChanged: {
                widgetLastCall.updateFilteredModelFunction();
            }
        }

        HistoryThreadModel {
            id: historyCallModel
            filter: HistoryFilter {}
            type: HistoryThreadModel.EventTypeVoice
            sort: HistorySort {
                sortField: "lastEventTimestamp"
                sortOrder: HistorySort.DescendingOrder
            }
        }

        ListView {
            id: listCall
            anchors.top: rectLastCallTitle.bottom
            height: contentHeight
            model: callList
            width:parent.width
            interactive: false
            spacing: 0
            clip: true

            delegate: Item {
                id: listCallItel
                width: ListView.view.width
                height: visibleContent.height+units.gu(2)
                MouseArea {
                    id: itemMouseArea
                    anchors.fill: parent
                    onClicked: {
                        if ("default" == launchermodular.settings.widgetCallClick){Qt.openUrlExternally("application:///dialer-app.desktop");}
                        if ("dial" == launchermodular.settings.widgetCallClick){Qt.openUrlExternally("tel:///"+participants);}
                    }
                    onPressAndHold: pageStack.push(Qt.resolvedUrl("lastcall/Settings.qml"))
                }
                Column {
                    id: visibleContent
                    anchors.fill: parent
                    width:parent.width;
                    spacing: 0

                    Text {
                        text: contactFullName.length > 0 ? contactFullName : participants;
                        color: launchermodular.settings.textColor;
                        font.pointSize: units.gu(1.2);
                    }
                    Text {
                        text: timestamp.toLocaleString(Qt.locale(), Locale.ShortFormat);
                        color: "#AEA79F";
                        font.pointSize: units.gu(1);
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
            anchors.top: rectLastCallTitle.bottom
            visible: listCall.count == 0
            height: units.gu(3)
            text: i18n.tr("No recent calls")
            color: launchermodular.settings.textColor
        }
    }
}
