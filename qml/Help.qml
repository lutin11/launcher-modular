import QtQuick 2.12
import QtQuick.Layouts 1.12
import QtGraphicalEffects 1.12
import Qt.labs.settings 1.0
import QtQuick.Controls 2.2
import Lomiri.Components 1.3
import Lomiri.Components.ListItems 1.3 as ListItem
import Lomiri.Components.Popups 1.3
import Lomiri.Components.Themes 1.3
import Platform 1.0
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

                Button {
                    id: howToUseButton
                    width: parent.width - units.gu(12)
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: i18n.tr("How to use")
                    onClicked: {
                        // the tour belongs to the launcher, so ask for it and go back to it
                        launchermodular.tutorialRequested = true
                        pageStack.pop()
                    }
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

                Item {
                    width: parent.width
                    height: diagnosticButton.height + units.gu(2)

                    Button {
                        id: diagnosticButton
                        anchors.centerIn: parent
                        text: i18n.tr("Diagnostic")
                        onClicked: PopupUtils.open(diagnosticDialog)
                    }

                    // List of the dependencies really found on this machine. The
                    // content is not translated: it is technical state, meant to
                    // be copied into a bug report.
                    Component {
                        id: diagnosticDialog
                        Dialog {
                            id: diagnosticDialogue
                            title: i18n.tr("Diagnostic")

                            Flickable {
                                width: units.gu(24)
                                height: units.gu(30)
                                contentHeight: diagnosticText.height
                                clip: true

                                TextEdit {
                                    id: diagnosticText
                                    width: parent.width
                                    // A TextEdit does not size itself to its
                                    // content: without this binding the dialog
                                    // opens empty (contentHeight stays 0).
                                    height: contentHeight
                                    readOnly: true
                                    selectByMouse: true
                                    text: Platform.diagnostics()
                                    // The dialog uses the light Lomiri surface:
                                    // a hard-coded white text would be invisible.
                                    color: Theme.palette.normal.backgroundText
                                    font.family: "Monospace"
                                    font.pixelSize: units.gu(1.6)
                                    wrapMode: Text.WordWrap
                                }
                            }

                            Button {
                                text: i18n.tr("Close")
                                onClicked: PopupUtils.close(diagnosticDialogue)
                            }
                        }
                    }
                }
            }
        }
    }
// HELP PAGE    
}

