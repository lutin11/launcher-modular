import QtQuick 2.12
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.0
import "../components"
import Qt.labs.settings 1.0
import Lomiri.History 0.1
import Lomiri.Contacts 0.1

Item {
    id: widgetLastCall
    width: listColumn.width/2
    height: rectLastCallTitle.height + (listCall.count > 0 ? listCall.contentHeight : emptyLabel.height) + units.gu(2.5)

    property ListModel filteredModel:  ListModel {}

    function updateFilteredModel() {
        filteredModel.clear();
        var numberOfVisibleItems = launchermodular.settings.numberOfCallWidget;
        var count = Math.min(historyCallModel.count, numberOfVisibleItems);
        for (var i = 0; i < count; i++) {
            // Get the participants value from the historyCallModel
            var participants = historyCallModel.get(i).participants;
            participants = participants.toString();
            filteredModel.append({
                participants: participants,  // Now a string
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
                text: i18n.tr("Last Call")
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
            model: filteredModel
            width:parent.width;
            interactive: false
            spacing: 0
            clip: true

            delegate: Item {
                id: listCallItel
                width: ListView.view.width
                height: visibleContent.height+units.gu(2.5)
                MouseArea {
                    id: itemMouseArea
                    anchors.fill: parent
                    onClicked: {
                        if ("default" === launchermodular.settings.widgetCallClick){Qt.openUrlExternally("application:///dialer-app.desktop")}
                        if ("dial" === launchermodular.settings.widgetCallClick){Qt.openUrlExternally("tel:///"+participants)}
                    }
                    onPressAndHold: pageStack.push(Qt.resolvedUrl("lastcall/Settings.qml"))
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
            visible: listCall.count === 0
            height: listCall.count === 0 ? units.gu(3) : 0
            text: i18n.tr("No recent calls")
            color: launchermodular.settings.textColor
        }
    }
}
