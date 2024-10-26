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
                text: i18n.tr("Back")
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

            property var details1: i18n.tr("You can configure how many last calls, last messages, and events you want to be displayed on the main page");
            property var description1: i18n.tr("To do so, long press on the widget to access to it's configurable page");
            property var details2: i18n.tr("On call settings, if the option for 'When clicked', is 'Open the dialer with number', a click on event will redirect it's number to the dialer");
            property var details3: i18n.tr("On message settings, if the option for 'When clicked', is 'Open the application with message', a click on event will redirect it's number to the messaging app");
            property var details4: i18n.tr("On event widget as event pages, the event are now displayed from the curent day");
            property var details5: i18n.tr("It's now possible to double click on event widget or event page to force re-fraiche the event list");
            property var details6: i18n.tr("A click on 'Alarmes' widget open the clock application");
            property var details7: i18n.tr("On picture page, a click on image open it in viewer");
            property var details8: i18n.tr("Todo");
            property var details9: i18n.tr("Initial release");

            ListModel {
                id: changeLogModel
            }


            Component.onCompleted: {
                changeLogModel.append({ version: "2.3.2", date: "2024-10-24", details: details1, description: description1 });
                changeLogModel.append({ version: "", date: "", details: details2, description: ""});
                changeLogModel.append({ version: "", date: "", details: details3, description: ""});
                changeLogModel.append({ version: "", date: "", details: details4, description: ""});
                changeLogModel.append({ version: "", date: "", details: details5, description: ""});
                changeLogModel.append({ version: "", date: "", details: details6, description: ""});
                changeLogModel.append({ version: "", date: "", details: details7, description: ""});
                changeLogModel.append({ version: "2.3.1", date: "2024-09-24", details: details8, description: ""});
                changeLogModel.append({ version: "2.3.0", date: "2024-10-02", details: details9, description: ""});
            }

            Rectangle {

                id: rectChangeLog
                color: "#111111"
                anchors {
                    fill: parent
                    topMargin: units.gu(6)
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
                                        text: i18n.tr("Version: ") + version
                                        visible: version.length > 0
                                        font.bold: true
                                        color: LomiriColors.orange
                                    }
                                    Text {
                                        text: i18n.tr(" | Date: ") + date
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
                                    color: if (index < changeLogModel.count && changeLogModel.get(index+1).version.length > 0){"white"} else {"black"}
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
                    spacing: units.gu(2)

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

                    Label {
                        text: i18n.tr("This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the <a href='https://www.gnu.org/licenses/gpl-3.0.en.html'>GNU General Public License</a> for more details.")
                        onLinkActivated: Qt.openUrlExternally(link)
                        wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                        color: "#ffffff"
                        width: parent.width
                        height: thank1Label.height + units.gu(2)
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Label {
                        text: i18n.tr("Maintainer") + " © 2024 David Cossé <a href='mailto:saveurlinux@disroot.org'>saveurlinux@disroot.org</a>"
                        wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                        color: "#ffffff"
                        width: parent.width
                        height: thank1Label.height + units.gu(2)
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Label {
                        text: i18n.tr("<a href='LAUNCHER MODULAR TRANSLATORS'>Modular Launcher-translators</a>")
                        onLinkActivated: pageStack.push(Qt.resolvedUrl("Translators.qml"))
                        wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                        color: "#ffffff"
                        width: parent.width
                        height: thank1Label.height + units.gu(2)
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }
}
