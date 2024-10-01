import QtQuick 2.12
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.0
import "../components"
import Qt.labs.settings 1.0
import Lomiri.History 0.1
import Lomiri.Contacts 0.1

Item {
    width: listColumn.width/2
    height: listCall.height+rectLastCall.height+emptyLabel.height
    Rectangle {
        id: widgetLastCall
        width: parent.width
                
          property string callNumber: ""

        Rectangle{
            id: rectLastCall
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
                text: launchermodular.settings.numberOfCallsWidget === 1 ? i18n.tr("Last Call") : i18n.tr("Last Calls")
                color: launchermodular.settings.textColor
            }
        }

        HistoryThreadModel {
            id: historyEventModel
            filter: HistoryFilter {}
            type: HistoryThreadModel.EventTypeVoice
            sort: HistorySort {
                sortField: "lastEventTimestamp"
                sortOrder: HistorySort.DescendingOrder
            }
        }

        Label {
            id: emptyLabel
            fontSize: "small"
            anchors.top: rectLastCall.bottom
            visible: listCall.count === 0
            height: if(listCall.height < 1){units.gu(3)}else{units.gu(2)}
            text: i18n.tr("No recent calls")
            color: launchermodular.settings.textColor
        }

        ListView {
            id: listCall
            anchors.top: rectLastCall.bottom
            model: historyEventModel
            height: contentHeight
            width:parent.width;
            interactive: false

            delegate: Column {
                visible: index < launchermodular.settings.numberOfCallsWidget;
                height: index == 0 ? contentHeight : 0
                width:parent.width;

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
                Component.onCompleted: if(index > 0){}else{widgetLastCall.callNumber = participants}
            }
            onCountChanged: {
                /* calculate ListView dimensions based on content */

                // get QQuickItem which is a root element which hosts delegate items
                var root = listCall.visibleChildren[0]
                var listViewHeight = 0

                // iterate over each delegate item to get their sizes
                for (var i = 0; i < root.visibleChildren.length; i++) {
                    listViewHeight += root.visibleChildren[i].height
                }

                listCall.height = listViewHeight
                widgetLastCall.height = listCall.height+rectLastMessage.height+emptyLabel.height+units.gu(3)
            }
        }

    }
    MouseArea {
        anchors.fill: parent
            onClicked: {
                if ("default" === launchermodular.settings.widgetCallClick){Qt.openUrlExternally("application:///dialer-app.desktop")}
                if ("dial" === launchermodular.settings.widgetCallClick){Qt.openUrlExternally("tel:///"+widgetLastCall.callNumber)}
            }
            onPressAndHold: pageStack.push(Qt.resolvedUrl("lastcall/Settings.qml"))
    }
    
}
