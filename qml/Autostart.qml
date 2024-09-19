import QtQuick 2.12
import QtQuick.Layouts 1.12
import QtGraphicalEffects 1.12
import Qt.labs.settings 1.0
import QtQuick.Controls 2.2
import Lomiri.Components 1.3
import Lomiri.Components.ListItems 1.3 as ListItem
import "pages"

Page {
    id: pageAbout

    header: PageHeader {
        id: aboutPage
        title: i18n.tr("Autostart Modular Launcher");
        StyleHints {
           foregroundColor: "#FFFFFF";
           backgroundColor: "#111111";
        }
        leadingActionBar.actions:
            Action {
                iconName: "back"
                text: "Back"
                onTriggered: {
                    pageStack.pop();
                }
            }
    }

    Rectangle {
        id:rect1
        color: "#111111"
        anchors {
            fill: parent
            topMargin: units.gu(6)
        }

        Item {
             width: parent.width
             height: parent.height

            Column {
                anchors {
                    left: parent.left
                    right: parent.right
                }

                ListItem.Header {
                    text: "<font color=\"#ffffff\">"+i18n.tr("How to Autostart Modular Launcher after booting")+"</font>"
                }

                Item {
                    width: parent.width
                    height: units.gu(2)
                }

                Item {
                    width: parent.width
                    height: autostartLabel.height + units.gu(2)
                    Label {
                        id: autostartLabel
                        text: i18n.tr("How to set Modular Launcher to start automatically when the device is booted. <br><br>More details in <a href='https://github.com/ruditimmermans/launcher-modular-service'>how to add a Modular Launcher systemd user service file to/on your device</a>")
                        onLinkActivated: Qt.openUrlExternally(link)
                        anchors.centerIn: parent
                        wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width - units.gu(12)
                        color: "#ffffff"
                    }
                }
            }
        }
    }
// AUTOSTART PAGE
}
