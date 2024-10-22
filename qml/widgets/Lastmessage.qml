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
    height: launchermodular.settings.numberOfMessageWidget+rectLastMessageTitle.height+emptyLabel.height
        
    property string messageNumber: ""

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
            model: historyThreadModel
            width:parent.width;
            interactive: false

            delegate: Column {
                visible: index < launchermodular.settings.numberOfMessageWidget;
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
                Text {
                    text: eventTextMessage;
                    elide: Text.ElideRight;
                    maximumLineCount: 1;
                    width: message.width;
                    color: launchermodular.settings.textColor;
                    font.pointSize: units.gu(1.1);
                    visible: launchermodular.settings.widgetMessageSummary;
                }
                Component.onCompleted: if(index > 0){}else{widgetLastMessage.messageNumber = participants}
            }
            onCountChanged: {
                /* calculate ListView dimensions based on content */

                // get QQuickItem which is a root element which hosts delegate items
                var root = listMessage.visibleChildren[0]
                var listViewHeight = 0

                // iterate over each delegate item to get their sizes
                for (var i = 0; i < launchermodular.settings.numberOfMessageWidget; i++) {
                    listViewHeight += root.visibleChildren[i].height
                }

                listMessage.height = listViewHeight
                widgetLastMessage.height = listMessage.height+rectLastMessageTitle.height+emptyLabel.height+units.gu(2.5)
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
    MouseArea {
        anchors.fill: parent
        onClicked: {
            if ("default" === launchermodular.settings.widgetMessageClick){Qt.openUrlExternally("application:///messaging-app.desktop")}
            if ("message" === launchermodular.settings.widgetMessageClick){Qt.openUrlExternally("message:///"+widgetLastMessage.messageNumber)}
        }
        onPressAndHold:pageStack.push(Qt.resolvedUrl("lastmessage/Settings.qml"))
            
    }

}
