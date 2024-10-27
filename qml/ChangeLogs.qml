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
        id: changeLogAboutView
        anchors.fill: parent
        currentIndex: 0

        // Page 1: Change Log
        Item {
            id: page1

            // 2.3.3
            property var details1: i18n.tr("Set how many calls to display!");
            property var description1: i18n.tr("To do this, long press on the widget to access its configuration page.");
            property var details2: i18n.tr("Set how many messages to display!");
            property var description2: i18n.tr("To do this, long press on the widget to access its configuration page.");
            property var details3: i18n.tr("Set how many event to display!");
            property var description3: i18n.tr("To do this, long press on the widget to access its configuration page.");
            property var details4: i18n.tr("Call redirection to phone app works!");
            property var description4: i18n.tr("On call settings, set the option for 'When clicked' to 'Open the dialer with number'");
            property var details5: i18n.tr("Message redirection to messaging app works!");
            property var description5: i18n.tr("On message settings, set the option for 'When clicked' to 'Open the application with message'");
            property var details6: i18n.tr("Force the event list refresh by double-clicking on the event widget!");
            property var description6:"";
            property var details7: i18n.tr("The event list show event from current day!");
            property var description7:"";
            property var details8: i18n.tr("Clicking on the 'Alarm' widget opens the clock!");
            property var description8:"";
            property var details9: i18n.tr("Open the photo by clicking on it!");
            property var description9:"";
            // 2.3.2
            property var details10: i18n.tr("Enable Autostart");
            property var description10: i18n.tr("Swipe up to configure the launcher, and click on 'Autostart");
            property var details11: i18n.tr("Correction for background display.");
            property var description11:"";
            property var details12: i18n.tr("Fix up 'Run a command in a terminal'");
            property var description12:"";
            // 2.3.1
            property var details13: i18n.tr("Resumption of the application.");
            property var description13: i18n.tr("This is the first release of Launcher Modular based on <a href='https://github.com/ruditimmermans/launcher-modular'>Ruditimmermans</a> ones, It contains, libraries updates and some fixes.");

            ListModel {
                id: changeLogModel
            }

            Component.onCompleted: {
                changeLogModel.append({ version: "2.3.2", date: "2024-10-24", details: details1, description: description1 });
                changeLogModel.append({ version: "", date: "", details: details2, description: description2});
                changeLogModel.append({ version: "", date: "", details: details3, description: description3});
                changeLogModel.append({ version: "", date: "", details: details4, description: description4});
                changeLogModel.append({ version: "", date: "", details: details5, description: description5});
                changeLogModel.append({ version: "", date: "", details: details6, description: description6});
                changeLogModel.append({ version: "", date: "", details: details7, description: description7});
                changeLogModel.append({ version: "", date: "", details: details8, description: description8});
                changeLogModel.append({ version: "", date: "", details: details9, description: description9});
                changeLogModel.append({ version: "2.3.1", date: "2024-09-29", details: details10, description: description10});
                changeLogModel.append({ version: "", date: "", details: details11, description: description11});
                changeLogModel.append({ version: "", date: "", details: details12, description: description12});
                changeLogModel.append({ version: "2.3.0", date: "2024-09-23", details: details13, description: description13});
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
                    anchors.leftMargin: units.gu(1)  // Adjust this value for left space
                    anchors.rightMargin: units.gu(1) // Adjust this value for right space

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
                                        color: "#E95420"
                                    }
                                    Text {
                                        text: i18n.tr(" | Date: ") + date
                                        visible: date.length > 0
                                        color: "#888888"
                                    }
                                }

                                Text {
                                    id: textDetail
                                    text: details
                                    color: "#FFFFFF"
                                    wrapMode: Text.WordWrap
                                    width: changeLogContainer.width
                                }
                                Text {
                                    id: textDescription
                                    text: description
                                    color: "#888888"
                                    visible: description.length > 0
                                    wrapMode: Text.WordWrap
                                    width: changeLogContainer.width
                                    font.pointSize: units.gu(1.2);
                                    onLinkActivated: Qt.openUrlExternally(link)
                                }
                                Rectangle {
                                    id: endLine
                                    width: changeLogContainer.width
                                    height: 5
                                    color: if (index < changeLogModel.count && changeLogModel.get(index+1).version.length > 0){"#FFFFFF"} else {"#111111"}
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
                    id: columnAbout
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
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Label {
                        text: i18n.tr("Maintainer") + " © 2024 David Cossé <a href='mailto:saveurlinux@disroot.org'>saveurlinux@disroot.org</a>"
                        wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                        color: "#ffffff"
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Label {
                        text: i18n.tr("<a href='LAUNCHER MODULAR TRANSLATORS'>Modular Launcher-translators</a>")
                        onLinkActivated: pageStack.push(Qt.resolvedUrl("Translators.qml"))
                        wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                        color: "#ffffff"
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }

    Button {
        id: swipeHintButtonNext
        visible: changeLogAboutView.currentIndex === 0
        width: units.gu(2)
        height: units.gu(2)
        anchors.right: parent.right
        anchors.rightMargin: units.gu(3)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        color:"transparent"

        Icon {
            id: swipeHintButtonNextIcon
            name: "go-next"
            width: units.gu(2)
            height: units.gu(2)
            color: "#E95420"
        }

        onClicked: {
            changeLogAboutView.currentIndex = 1;
        }
    }

    Button {
        id: swipeHintButtonPrevious
        visible: changeLogAboutView.currentIndex === 1
        width: units.gu(2)
        height: units.gu(2)
        anchors.left: parent.left
        anchors.leftMargin: units.gu(3)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        color:"transparent"

        Icon {
            id: swipeHintButtonPreviousIcon
            name: "go-previous"
            width: units.gu(2)
            height: units.gu(2)
            color: "#E95420"
        }

        onClicked: {
            changeLogAboutView.currentIndex = 0;
        }
    }
}
