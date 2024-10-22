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
    height: launchermodular.settings.numberOfCallWidget+rectLastCallTitle.height+emptyLabel.height

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
            visible: listCall.count > 0

            delegate: Column {
                visible: index < launchermodular.settings.numberOfCallWidget;
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
                Component.onCompleted: if(index > 0){}else{call.callNumber = participants}
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
    MouseArea {
        anchors.fill: parent
            onClicked: {
                if ("default" === launchermodular.settings.widgetCallClick){Qt.openUrlExternally("application:///dialer-app.desktop")}
                if ("dial" === launchermodular.settings.widgetCallClick){Qt.openUrlExternally("tel:///"+call.callNumber)}
            }
            onPressAndHold: pageStack.push(Qt.resolvedUrl("lastcall/Settings.qml"))
    }
    
}
