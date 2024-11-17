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

            property var emptyDescription:"";
            // 2.3.3
            property var details1: i18n.tr("Set how many calls to display!");
            property var description1: i18n.tr("To do this, long press on the widget to access its configuration page.");
            property var details2: i18n.tr("Set how many messages to display!");
            property var description2: i18n.tr("To do this, long press on the widget to access its configuration page.");
            property var details3: i18n.tr("Set how many events to display!");
            property var description3: i18n.tr("To do this, long press on the widget to access its configuration page.");
            property var details4: i18n.tr("Call redirection to phone app works!");
            property var description4: i18n.tr("On call settings, set the option for 'When clicked' to 'Open the dialer with number'");
            property var details5: i18n.tr("Message redirection to messaging app works!");
            property var description5: i18n.tr("On message settings, set the option for 'When clicked' to 'Open the application with message'");
            property var details6: i18n.tr("Force the event list to refresh by double-clicking on the event widget!");
            property var details7: i18n.tr("The event list shows event from current day!");
            property var details8: i18n.tr("Clicking on the 'Alarm' widget opens the clock!");
            property var details9: i18n.tr("Open the photo by clicking on it!");
            // 2.3.2
            property var details10: i18n.tr("Enable Autostart");
            property var description10: i18n.tr("Swipe up to configure the launcher, and click on 'Autostart");
            property var details11: i18n.tr("Correction for background display.");
            property var details12: i18n.tr("Fix up 'Run a command in a terminal'");
            // 2.3.1
            property var details13: i18n.tr("Resumption of the application.");
            property var description13: i18n.tr("This is the first release of Launcher Modular based on <a href='https://github.com/ruditimmermans/launcher-modular'>Ruditimmermans</a> ones, It contains, libraries updates and some fixes.");
            // 2.3.4
            property var details14: i18n.tr("Addition of a new page for RSS feeds");
            property var description14:"On Rss setting page, you can add a list of RSS feeds";
            property var details15: i18n.tr("Update translations");
            property var details16: i18n.tr("Improved 'Picture' page display performance");
            // 2.3.5
            property var details17: i18n.tr("Display contact name if exists on message and call widget");
            property var details18: i18n.tr("Improved 'Picture' page display performance");
            property var details19: i18n.tr("Update translations");
            // 2.3.6
            property var details20: i18n.tr("Fix launching Libertine applications");
            property var details21: i18n.tr("Fix launching favorite applications");
            property var details22: i18n.tr("Update weather on refreshing home page");
            property var details23: i18n.tr("Added the ability to run a calculation from the search bar");
            property var details24: i18n.tr("Update translations");

            ListModel {
                id: changeLogModel
            }

            Component.onCompleted: {
                changeLogModel.append({ version: "2.3.6", date: "2024-11-17", details: details20, description: emptyDescription});
                changeLogModel.append({ version: "", date: "", details: details21, description: emptyDescription});
                changeLogModel.append({ version: "", date: "", details: details22, description: emptyDescription});
                changeLogModel.append({ version: "", date: "", details: details23, description: emptyDescription});
                changeLogModel.append({ version: "", date: "", details: details24, description: emptyDescription});
                changeLogModel.append({ version: "2.3.5", date: "2024-11-03", details: details17, description: emptyDescription });
                changeLogModel.append({ version: "", date: "", details: details18, description: emptyDescription });
                changeLogModel.append({ version: "", date: "", details: details19, description: emptyDescription });
                changeLogModel.append({ version: "2.3.4", date: "2024-10-31", details: details14, description: description14 });
                changeLogModel.append({ version: "", date: "", details: details15, description: emptyDescription });
                changeLogModel.append({ version: "", date: "", details: details16, description: emptyDescription });
                changeLogModel.append({ version: "2.3.3", date: "2024-10-24", details: details1, description: description1 });
                changeLogModel.append({ version: "", date: "", details: details2, description: description2});
                changeLogModel.append({ version: "", date: "", details: details3, description: description3});
                changeLogModel.append({ version: "", date: "", details: details4, description: description4});
                changeLogModel.append({ version: "", date: "", details: details5, description: description5});
                changeLogModel.append({ version: "", date: "", details: details6, description: emptyDescription});
                changeLogModel.append({ version: "", date: "", details: details7, description: emptyDescription});
                changeLogModel.append({ version: "", date: "", details: details8, description: emptyDescription});
                changeLogModel.append({ version: "", date: "", details: details9, description: emptyDescription});
                changeLogModel.append({ version: "2.3.2", date: "2024-09-29", details: details10, description: description10});
                changeLogModel.append({ version: "", date: "", details: details11, description: emptyDescription});
                changeLogModel.append({ version: "", date: "", details: details12, description: emptyDescription});
                changeLogModel.append({ version: "2.3.1", date: "2024-09-23", details: details13, description: description13});
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
                    anchors.topMargin: units.gu(1)
                    anchors.fill: parent
                    model: changeLogModel
                    spacing: units.gu(1)
                    anchors.leftMargin: units.gu(1)  // Adjust this value for left space
                    anchors.rightMargin: units.gu(1) // Adjust this value for right space

                    delegate: Item {
                        id: changeLogContainer
                        width: parent.width
                        height: versionLine.height + textDetail.implicitHeight + textDescription.implicitHeight + endLine.height
                        Rectangle {
                            id: changeLogItem
                            height: versionLine.height + textDetail.implicitHeight + textDescription.implicitHeight + endLine.height
                            width: parent.width
                            opacity: 0.9
                            color: "#111111"

                            Column {
                                //spacing: 5

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
                                    visible: description.length > 1
                                    wrapMode: Text.WordWrap
                                    width: changeLogContainer.width
                                    font.pointSize: units.gu(1.2);
                                    onLinkActivated: Qt.openUrlExternally(link)
                                }
                                Rectangle {
                                    id: endLine
                                    width: changeLogContainer.width
                                    height: 1
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
                id:rectAbout
                color: "#111111"
                anchors {
                    fill: parent
                    topMargin: units.gu(6)
                }

                Flickable {
                    id: aboutListItems
                    anchors.fill: parent
                    contentHeight: columnListItems.height
                    flickableDirection: Flickable.VerticalFlick
                    clip: true

                    Column {
                        id: columnListItems
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            topMargin: units.gu(1)
                        }

                        Item {
                            width: parent.width
                            height: units.gu(5)
                            Label {
                                text: "Modular Launcher"
                                anchors.horizontalCenter: parent.horizontalCenter
                                fontSize: "x-large"
                                color: "#ffffff"
                            }
                        }

                        Item {
                            width: parent.width
                            height: units.gu(14)

                            LomiriShape {
                                radius: "medium"
                                source: Image {
                                    source: Qt.resolvedUrl("../assets/logo.svg");
                                }
                                height: units.gu(12);
                                width: height;
                                anchors.horizontalCenter: parent.horizontalCenter;
                            }
                        }

                        Item {
                            width: parent.width
                            height: units.gu(4)
                            Label {
                                text: ("v"+launchermodular.appVersion)
                                fontSize: "large"
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: "#ffffff"
                            }
                        }

                        Item {
                            width: parent.width
                            height: units.gu(2)
                        }

                        Item{
                            width: parent.width
                            height: units.gu(2)

                            Row {
                                LomiriShape {
                                    id: thumbupLeft
                                    radius: "medium"
                                    source: Image {
                                        source: Qt.resolvedUrl("../assets/thumbup-full.svg");
                                    }
                                    height: units.gu(2);
                                    width: units.gu(2);
                                    anchors.left: parent.right
                                    anchors.leftMargin: units.gu(1)
                                }

                                Label {
                                    id: thumbupText
                                    anchors.left: thumbupLeft.right
                                    text: i18n.tr("If you like this app, please rank it on OpenStore")
                                    color: "#ffffff"
                                }

                                LomiriShape {
                                    radius: "medium"
                                    source: Image {
                                        source: Qt.resolvedUrl("../assets/thumbup-full.svg");
                                    }
                                    height: units.gu(2);
                                    width: units.gu(2);
                                    anchors.left: thumbupText.right
                                    anchors.rightMargin: units.gu(3)
                                }
                            }
                        }

                        Item {
                            width: parent.width
                            height: units.gu(2)
                        }

                        Item {
                            width: parent.width
                            height: appLabel.height + units.gu(2)
                            Label {
                                id: appLabel
                                text: i18n.tr("A modular launcher for Ubuntu Touch")
                                anchors.horizontalCenter: parent.horizontalCenter
                                wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                                horizontalAlignment: Text.AlignHCenter
                                width: parent.width
                                color: "#ffffff"
                            }
                        }

                        Item {
                            width: parent.width
                            height: licenceLabel.height + units.gu(2)
                            Label {
                                id: licenceLabel
                                text: i18n.tr("This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the <a href='https://www.gnu.org/licenses/gpl-3.0.en.html'>GNU General Public License</a> for more details.")
                                onLinkActivated: Qt.openUrlExternally(link)
                                anchors.horizontalCenter: parent.horizontalCenter
                                wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                                horizontalAlignment: Text.AlignHCenter
                                width: parent.width
                                color: "#ffffff"
                            }
                        }

                        Item {
                            width: parent.width
                            height: sourceLabel.height + units.gu(2)
                            Label {
                                id: sourceLabel
                                text: "<a href='https://github.com/lutin11/launcher-modular'>" + i18n.tr("SOURCE") + "</a> | <a href='https://github.com/lutin11/launcher-modular/issues'>" + i18n.tr("ISSUES") + "</a>"
                                onLinkActivated: Qt.openUrlExternally(link)
                                anchors.horizontalCenter: parent.horizontalCenter
                                wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                                horizontalAlignment: Text.AlignHCenter
                                width: parent.width
                                color: "#ffffff"
                            }
                        }

                        Item {
                            width: parent.width
                            height: maintainerLabel.height + units.gu(2)
                            Label {
                                id: maintainerLabel
                                text: i18n.tr("Maintainer") + " © 2024 David Cossé <a href='mailto:saveurlinux@disroot.org'>saveurlinux@disroot.org</a>"
                                anchors.horizontalCenter: parent.horizontalCenter
                                wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                                horizontalAlignment: Text.AlignHCenter
                                width: parent.width
                                color: "#ffffff"
                            }
                        }

                        Item {
                            width: parent.width
                            height: previousMaintainerLabel.height + units.gu(2)
                            Label {
                                id: previousMaintainerLabel
                                text: i18n.tr("Copyright") + " © 2024 David Cossé"
                                anchors.horizontalCenter: parent.horizontalCenter
                                wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                                horizontalAlignment: Text.AlignHCenter
                                width: parent.width
                                color: "#ffffff"
                            }
                        }

                        Item {
                            width: parent.width
                            height: translatorsLabel.height + units.gu(2)
                            Label {
                                id: translatorsLabel
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: i18n.tr("<a href='LAUNCHER MODULAR TRANSLATORS'>Modular Launcher-translators</a>")
                                anchors.verticalCenter: parent.verticalCenter
                                wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                                horizontalAlignment: Text.AlignHCenter
                                width: parent.width
                                color: "#ffffff"

                                onLinkActivated: pageStack.push(Qt.resolvedUrl("Translators.qml"))
                            }
                        }
                    }
                }
            }
        }
    }

    Button {
        id: swipeHintButtonNext
        visible: changeLogAboutView.currentIndex == 0
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
        visible: changeLogAboutView.currentIndex == 1
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
