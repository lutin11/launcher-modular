import QtQuick 2.12
import QtQuick.Controls 2.2
import Qt.labs.settings 1.0
import Lomiri.Components 1.3
import Lomiri.Components.ListItems 1.3 as ListItemHeader
import MySettings 1.0
import NetworkHelper 1.0


Page {
    id: pageSettingsRss
    // Injected by Pagemanagement: the settings entry of a page knows which
    // page it configures (pageIndex is kept for compatibility, pageUid is the
    // stable identifier used by the per-page configuration).
    property int pageIndex: -1
    property string pageName: ""
    property string pageUid: ""
    anchors.fill: parent

    property string rssPageName: i18n.tr("rss") // do not remove, use pour Po files

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
        id:mainRssSettings
        anchors.fill: parent
        color: "#111111"
        anchors.topMargin: units.gu(6)
        height: units.gu(60)

        ListItemHeader.Header {
            id: rssSettingsHeader
            width: parent.width
            text: "<font color=\"#ffffff\">"
                  + i18n.tr("Settings for 'RSS' page")
                  + "</font>"
        }

        Flickable {
            id: flickableRssSettings
            anchors {
                top: rssSettingsHeader.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
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
                            right: headerRss.right
                            rightMargin: units.gu(1)
                            verticalCenter: parent.verticalCenter
                        }
                        height: parent.height*0.5
                        inputMethodHints: Qt.ImhNoPredictiveText
                        placeholderText: ""
                        // to have a placeholder color that is different that from theme
                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: units.gu(1)
                            anchors.rightMargin: units.gu(0.5)
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            color: "#aaaaaa"
                            text: i18n.tr("ex: https://omgubuntu.co.uk/feed")
                            visible: rssField.text.length === 0
                        }

                        property string urlToSave: ""

                        function isValidUrl(url) {
                            // Light sanity check only; QUrl and the reachability
                            // test in NetworkHelper do the real validation. The
                            // former pattern refused ports, query strings and
                            // uppercase letters, i.e. many valid feeds.
                            var pattern = /^https?:\/\/[^\s\/]+\.[^\s]+$/i;
                            return pattern.test(url);
                        }

                        // The field itself reports the Return/Enter key through
                        // accepted(); the attached Keys handler is bypassed as
                        // soon as the field consumes the key event.
                        onAccepted: {
                            var url = rssField.text.trim()
                            if (!rssField.isValidUrl(url)) {
                                errorLine.visible = true
                                invalidTextError.text = i18n.tr("Invalid URL format")
                                return
                            }
                            rssField.urlToSave = url;  // Store text in temporary property
                            NetworkHelper.checkUrlReachable(url)
                        }
                        maximumLength: 100
                    }

                    Connections {
                        target: NetworkHelper
                        onUrlCheckCompleted: function(reachable, isRssFeed) {
                            if (reachable && isRssFeed) {
                                if (DEBUG_MODE) console.log("URL " + rssField.urlToSave + " is a valid RSS feed");
                                RssModel.save(rssField.urlToSave);
                                rssField.text = ""
                                errorLine.visible = false
                                launchermodular.settings.rssFeedChanged = true
                            } else if (reachable) {
                                if (DEBUG_MODE) console.log("URL is reachable but not a valid RSS feed");
                                errorLine.visible = true
                                invalidTextError.text = "URL is reachable but not a valid RSS feed"
                            } else {
                                if (DEBUG_MODE) console.log("URL not reachable");
                                errorLine.visible = true
                                invalidTextError.text = "URL not reachable"
                            }
                        }
                    }
                }

                delegate: Item {
                    width: parent.width
                    height: units.gu(6)
                    anchors {
                        rightMargin: units.gu(2)
                        leftMargin: units.gu(2)
                    }

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
