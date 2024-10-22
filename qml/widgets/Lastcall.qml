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

    property string callNumber: ""

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
            model: historyCallModel
            width:parent.width;
            interactive: false
            spacing: 0
            clip: true
            visible: listCall.count > 0

            delegate: Column {
                id: listCallItel
                width: ListView.view.width
                height: visibleContent.height+units.gu(2.5)
                visible: index < launchermodular.settings.numberOfCallWidget;
                MouseArea {
                    id: itemMouseArea
                    anchors.fill: parent
                    onClicked: {
                        console.log("Clicked on:" + index + " - " + participants)
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
                /* calculate ListView dimensions based on content */

                // get QQuickItem which is a root element which hosts delegate items
                var root = listCall.visibleChildren[0]
                var listViewHeight = 0

                // iterate over each delegate item to get their sizes
                for (var i = 0; i < launchermodular.settings.numberOfCallWidget; i++) {
                    listViewHeight += root.visibleChildren[i].height
                }

                listCall.height = listViewHeight
                widgetLastCall.height = listCall.height+rectLastCallTitle.height+emptyLabel.height+units.gu(2.5)
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
