import QtQuick 2.12
import QtQuick.Layouts 1.12
import QtGraphicalEffects 1.12
import Qt.labs.settings 1.0
import QtQuick.Controls 2.2
import Lomiri.Components 1.3
import "pages"

Page {
    id: pageAbout

    header: PageHeader {
        id: aboutPage
        title: i18n.tr("About");
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
                    height: units.gu(5)
                    Label {
                        text: "Modular Launcher"
                        anchors.centerIn: parent
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
                        height: units.gu(12); width: height;
                        anchors.centerIn: parent;


                    } // shape
                }/// item

                Item {
                    width: parent.width
                    height: units.gu(4)
                    Label {
                        text: ("v"+launchermodular.appVersion)
                        fontSize: "large"
                        anchors.centerIn: parent
                        color: "#ffffff"
                    }
                }

                Item {
                    width: parent.width
                    height: units.gu(2)
                }

                Item {
                    width: parent.width
                    height: thankLabel.height + units.gu(2)
                    Label {
                        id: appLabel
                        text: i18n.tr("A modular launcher for Ubuntu Touch")
                        anchors.centerIn: parent
                        wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width - units.gu(12)
                        color: "#ffffff"
                    }
                }

                Item {
                    width: parent.width
                    height: sourceLabel.height + units.gu(2)
                    Label {
                        id: sourceLabel
                        text: i18n.tr("This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the <a href='https://www.gnu.org/licenses/gpl-3.0.en.html'>GNU General Public License</a> for more details.")
                        onLinkActivated: Qt.openUrlExternally(link)
                        anchors.centerIn: parent
                        wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width - units.gu(12)
                        color: "#ffffff"
                    }
                }

                Item {
                    width: parent.width
                    height: donateLabel.height + units.gu(2)
                    Label {
                        id: donateLabel
                        text: "<a href='https://github.com/lutin11/launcher-modular'>" + i18n.tr("SOURCE") + "</a> | <a href='https://github.com/lutin11/launcher-modular/issues'>" + i18n.tr("ISSUES") + "</a>"
                        onLinkActivated: Qt.openUrlExternally(link)
                        anchors.centerIn: parent
                        wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width - units.gu(12)
                        color: "#ffffff"
                    }
                }

                Item {
                    width: parent.width
                    height: thankLabel.height + units.gu(2)
                    Label {
                        id: thankLabel
                        text: i18n.tr("Maintainer") + " © 2024 David Cossé <a href='mailto:saveurlinux@disroot.org'>saveurlinux@disroot.org</a>"
                        anchors.centerIn: parent
                        wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width - units.gu(12)
                        color: "#ffffff"
                    }
                }

                Item {
                    width: parent.width
                    height: thank1Label.height + units.gu(2)
                    Label {
                        id: thank1Label
                        text: i18n.tr("Copyright") + " © 2019–2020 Jimmy Lejeune"
                        anchors.centerIn: parent
                        wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width - units.gu(12)
                        color: "#ffffff"
                    }
                }

                Item {
                    width: parent.width
                    height: donateLabel.height + units.gu(2)
                    Label {
                        id: translatorsLabel
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: i18n.tr("<a href='LAUNCHER MODULAR TRANSLATORS'>Modular Launcher-translators</a>")
                        anchors.centerIn: parent
                        wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width - units.gu(12)
                        color: "#ffffff"

                        onLinkActivated: pageStack.push(Qt.resolvedUrl("Translators.qml"))
                    }
                }
            }
        }
    }
// ABOUT PAGE
}
