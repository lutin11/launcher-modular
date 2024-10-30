import QtQuick 2.12
import QtQuick.Controls 2.2
import Qt.labs.settings 1.0
import Lomiri.Components 1.3
import MySettings 1.0
import NetworkHelper 1.0


Page {
    id: pageSettingsRss
    anchors.fill: parent

    Component.onCompleted: {
        RssModel.dbInit()
    }

    header: PageHeader {
        id: headerSettings
        title: i18n.tr("Settings Page");
        width: parent.width
        leadingActionBar.actions: [
            Action {
                iconName: "back"
                text: i18n.tr("Back")
                onTriggered: {
                    pageStack.pop();
                }
            }
        ]
    }

    Rectangle {
        id:mainsettings
        anchors.fill: parent
        color: "#111111"
        anchors.topMargin: units.gu(6)
        height: units.gu(60)

        Flickable {
            id: flickableSettings
            anchors.fill: parent
            //contentHeight: rssList.height
            flickableDirection: Flickable.VerticalFlick
            clip: true

            ListView {
                id: rssList
                anchors.fill: parent
                model: RssModel.itemModel
                interactive: false

                header:Rectangle {
                    id: headerRss
                    height: units.gu(6)
                    width: parent.width
                    color: "transparent"

                    Icon {
                        id: iconRss
                        anchors {
                            left: headerRss.left
                            rightMargin: units.gu(1)
                            leftMargin: units.gu(1)
                            verticalCenter: parent.verticalCenter
                        }
                        height: parent.height*0.5
                        width: height
                        source: "assets/icon.svg"

                        MouseArea {
                            anchors.fill: parent
                            onClicked:{
                                if(rssField.text.length > 0){
                                   rssField.text = ""
                                   rssField.focus = false
                                }
                            }
                        }
                    }

                    TextField {
                        id: rssField
                        anchors {
                            left: iconRss.right
                            leftMargin: units.gu(1)
                            rightMargin: units.gu(1)
                            verticalCenter: parent.verticalCenter
                        }
                        height: parent.height*0.5
                        width: parent.width - iconRss.width - units.gu(1)
                        inputMethodHints: Qt.ImhUrlCharactersOnly
                        placeholderText: i18n.tr("new rss")

                        property string urlToSave: ""

                        function isValidUrl(url) {
                            var pattern = /^(https?:\/\/)?([\da-z.-]+)\.([a-z.]{2,6})([/\w .-]*)*\/?$/;
                            return pattern.test(url);
                        }

                        Keys.onReturnPressed: {
                            if (isValidUrl(rssField.text)) {
                                rssField.urlToSave = rssField.text;  // Store text in temporary property
                                NetworkHelper.checkUrlReachable(rssField.text)
                            } else {
                                console.log("Invalid URL format")
                                errorLine.visible = true
                                invalidTextError.text = "Invalid URL format"
                            }
                        }
                        maximumLength: 100
                    }

                    Connections {
                        target: NetworkHelper
                        onUrlCheckCompleted: function(reachable, isRssFeed) {
                            if (reachable && isRssFeed) {
                                console.log("URL " + rssField.urlToSave + " is a valid RSS feed");
                                RssModel.save(rssField.urlToSave);
                                rssField.text = ""
                                errorLine.visible = false
                            } else if (reachable) {
                                console.log("URL is reachable but not a valid RSS feed");
                                errorLine.visible = true
                                invalidTextError.text = "URL is reachable but not a valid RSS feed"
                            } else {
                                console.log("URL not reachable");
                                errorLine.visible = true
                                invalidTextError.text = "URL not reachable"
                            }
                        }
                    }
                }

                delegate: Item {
                    width: parent.width
                    height: units.gu(6)

                    Column {
                        id: aRssLine
                        width: parent.width

                        spacing: 0

                        Row {
                            id: rssRowUri
                            width: parent.width

                            Rectangle {
                                id: rssUri
                                width: rssRowUri.width - units.gu(4)
                                height: units.gu(4)
                                color: "#333333"

                                Text {
                                    text: model.rss_uri
                                    color: "#ffffff"
                                    anchors.verticalCenter:parent.verticalCenter
                                    anchors.leftMargin: units.gu(1)
                                }
                            }

                            Button {
                                id: deleteRssButton
                                width: units.gu(4)
                                height: units.gu(4)
                                anchors.left: rssUri.right
                                anchors.top: parent.top
                                color: "#ED3146"
                                text: i18n.tr("Delete")

                                Icon {
                                    id: deleteRss
                                    name: "edit-delete"
                                    width: units.gu(2)
                                    height: units.gu(2)
                                    color: "#E95420"
                                }

                                onClicked: {
                                    RssModel.remove(rssList.model.id)
                                }
                            }
                        }

                        Rectangle {
                            id: endLine
                            width: aRssLine.width
                            height: 1
                            color: "#111111"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }
        } //flickable
    } //rectangle settings
    Item {
        id: errorLine
        width: parent.width
        height: units.gu(2) // Set a height to make it visible
        visible : false
        z: 10
        Rectangle {
            id: urlError
            width: parent.width
            height: units.gu(2) // Adjust height if necessary
            color: "red"
            anchors.horizontalCenter: parent.horizontalCenter // Center it horizontally
            anchors.bottom: parent.bottom // Anchor to the bottom of the parent

            Text {
                id: invalidTextError
                text: i18n.tr("Invalid url")
                color: "#ffffff"
                anchors.centerIn: parent // Center text within the rectangle
            }
        }
    }
}
