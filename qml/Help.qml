import QtQuick 2.4
import QtQuick.Layouts 1.12
import QtGraphicalEffects 1.0
import Qt.labs.settings 1.0
import QtQuick.Controls 2.2
import Ubuntu.Components 1.3
import Ubuntu.Components.ListItems 1.3 as ListItem
import "pages"

Page {
    id: pageHelp

    header: PageHeader {
        id: helpPage
        title: i18n.tr("Modular Launcher Help");
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

                Item {
                    width: parent.width
                    height: widgetSettingHelp.height + units.gu(2)
                    Label {
                        id: widgetSettingHelp
                        text: i18n.tr("<br><b>Click and hold the widget to change its settings.</b>")
                        anchors.centerIn: parent
                        wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width - units.gu(12)
                        color: "#ffffff"
                    }
                }

                Item {
                    width: parent.width
                    height: addNewPageHelp.height + units.gu(2)
                    Label {
                        id: addNewPageHelp
                        text: i18n.tr("<br><b>To add a new page, go to 'Manage page' and click on the '+' on the top right.</b>")
                        anchors.centerIn: parent
                        wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width - units.gu(12)
                        color: "#ffffff"
                    }
                }

                Item {
                    width: parent.width
                    height: pageSettingHelp.height + units.gu(2)
                    Label {
                        id: pageSettingHelp
                        text: i18n.tr("<br><b>To change page settings, go to 'Manage page' and click the page.</b>")
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
// HELP PAGE    
}

