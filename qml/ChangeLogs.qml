import QtQuick 2.12
import QtQuick.Layouts 1.12
import QtGraphicalEffects 1.12
import Qt.labs.settings 1.0
import QtQuick.Controls 2.2
import Lomiri.Components 1.3
import "pages"

Page {
    id: changeLogPage

    header: PageHeader {
        id: changeLogPageHeader
        title: i18n.tr("Change Log");
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
        id: changeLogPageTopBorder
        height: units.gu(0.1)
        anchors.left: parent.left
        anchors.right: parent.right
        color: "#E95420"
    }

    SwipeView {
        id: view
        anchors.fill: parent
        currentIndex: 0

        // Page 1: Change Log
        Item {
            Rectangle {

                id: rectChangeLog
                color: "#111111"
                anchors {
                    fill: parent
                    topMargin: units.gu(6)
                }


                // Model to store change log items
                ListModel {
                    id: changeLogModel

                    ListElement { version: "2.3.2"; date: "2024-10-24"; details: "You can configure how many last calls, last messages, and events you want to be displayed on the main page"; description: "To do so, long press on the widget to access to it's configurable page"}
                    ListElement { version: ""; date: ""; details: "On call settings, if the option for 'When clicked', is 'Open the dialer with number', a click on event will redirect it's number to the dialer"; description: ""}
                    ListElement { version: ""; date: ""; details: "On message settings, if the option for 'When clicked', is 'Open the application with message', a click on event will redirect it's number to the messaging app"; description: ""}
                    ListElement { version: ""; date: ""; details: "On event widget as event pages, the event are now displayed from the curent day"; description: ""}
                    ListElement { version: ""; date: ""; details: "It's now possible to double click on event widget or event page to force re-fraiche the event list"; description: ""}
                    ListElement { version: ""; date: ""; details: "A click on 'Alarmes' widget open the clock application"; description: ""}
                    ListElement { version: ""; date: ""; details: "On picture page, a click on image open it in viewer"; description: ""}
                    ListElement { version: "2.3.1"; date: "2024-09-24"; details: "Todo"; description: ""}
                    ListElement { version: "2.3.0"; date: "2024-10-02"; details: "Initial release"; description: ""}
                }

                ListView {
                    id: changeLogModelListView
                    anchors.topMargin: units.gu(6)
                    anchors.fill: parent
                    model: changeLogModel
                    spacing: 10

                    delegate: Item {
                        id: changeLogContainer
                        width: parent.width
                        height: versionLine.height + textDetail.implicitHeight + textDescription.implicitHeight + endLine.height + 20
                        Rectangle {
                            id: changeLogItem
                            height: units.gu(5)
                            width: parent.width
                            opacity: 0.9
                            color: "#111111"

                            Column {
                                spacing: 5

                                Row {
                                    id: versionLine

                                    Text {
                                        text: "Version: " + version
                                        visible: version.length > 0
                                        font.bold: true
                                        color: "blue"
                                    }
                                    Text {
                                        text: " | Date: " + date
                                        visible: date.length > 0
                                        color: "gray"
                                    }
                                }

                                Text {
                                    id: textDetail
                                    text: details
                                    color: "white"
                                    wrapMode: Text.WordWrap
                                    width: changeLogContainer.width
                                }
                                Text {
                                    id: textDescription
                                    text: description
                                    color: "grey"
                                    visible: description.length > 0
                                    wrapMode: Text.WordWrap
                                    width: changeLogContainer.width
                                    font.pointSize: units.gu(1.2);
                                }
                                Rectangle {
                                    id: endLine
                                    width: changeLogContainer.width
                                    height: 5
                                    color: if (index < changeLogModel.count && changeLogModel.get(index+1).version.length > 0){"white"} else {"grey"}
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }
                    }
                }

            }
        }


        // Page 2: About
        Item {
            Rectangle {

                id: rectAbout
                color: "#111111"
                anchors {
                    fill: parent
                    topMargin: units.gu(6)
                }

                Column {
                    anchors.centerIn: parent

                    Label {
                        text: "Modular Launcher"
                        fontSize: "x-large"
                        color: "#ffffff"
                    }

                    Image {
                        source: "../assets/logo.svg"
                        height: units.gu(12)
                        width: height
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Label {
                        text: "v" + launchermodular.appVersion
                        fontSize: "large"
                        color: "#ffffff"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Label {
                        text: i18n.tr("A modular launcher for Ubuntu Touch")
                        wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                        color: "#ffffff"
                        width: parent.width - units.gu(12)
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    // Other labels for license, source, etc., can be added similarly.
                }
            }
        }
    }
}
