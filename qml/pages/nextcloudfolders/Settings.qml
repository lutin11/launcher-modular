import QtQuick 2.12
import QtQuick.Controls 2.2
import Qt.labs.settings 1.0
import Qt.labs.folderlistmodel 2.12
import Lomiri.Components 1.3
import Lomiri.Components.ListItems 1.3 as ListItemHeader
import Lomiri.Components.Themes 1.3
import QtQuick.Layouts 1.12

Page {
    id: pageSettingsNextcloudFolders

    property string nextcloudPageName: i18n.tr("nextcloudFolders") // do not remove, use pour Po files

    property string testSucced: i18n.tr("Test it !")
    property bool serverUrl: false
    property bool loading: false
    property string errorMessage: ""

    function davUrl() {
        var base = launchermodular.settings.nextcloudUrl.replace(/\/+$/, "")
        return base + "/remote.php/dav/files/" + encodeURIComponent(launchermodular.settings.nextcloudUser) + "/"
    }

    function testConnexion() {
        loading = true
        testSucced = ""

        var xhr = new XMLHttpRequest()
        xhr.open("PROPFIND", davUrl())
        xhr.setRequestHeader("Depth", "1")
        xhr.setRequestHeader("Content-Type", "application/xml; charset=utf-8")
        xhr.setRequestHeader("Authorization", "Basic " + Qt.btoa(launchermodular.settings.nextcloudUser + ":" + launchermodular.settings.nextcloudPassword))

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            loading = false

            if (xhr.status === 207) {
                testSucced = i18n.tr("Success !")
            } else if (xhr.status === 401) {
                errorMessage = i18n.tr("Authentication failed. Check username/app password.")
            } else if (xhr.status === 0) {
                errorMessage = i18n.tr("Network error. Check server URL and connectivity.")
            } else {
                errorMessage = i18n.tr("Error %1 while loading folder.").arg(xhr.status)
            }
            if (errorMessage !== "") {
                testSucced = i18n.tr("Failed")
                console.log(errorMessage)
            }
        }

        var body = '<?xml version="1.0" encoding="utf-8" ?>' +
            '<d:propfind xmlns:d="DAV:">' +
            '<d:prop><d:resourcetype/><d:displayname/></d:prop>' +
            '</d:propfind>'
        xhr.send(body)
    }

    header: PageHeader {
        id: headerNextcloudSettings
        title: i18n.tr("Nextcloud folders")
        leadingActionBar.actions: [
            Action {
                iconName: "back"
                text: "Back"
                onTriggered: pageStack.pop()
            }
        ]
    }

    Rectangle {
        id: nextcloudSettings
        anchors.fill: parent
        color: "#111111"
        anchors.topMargin: units.gu(6)
        height: units.gu(60)

        Flickable {
            id: nextcloudFlickableSettings
            anchors.fill: parent
            flickableDirection: Flickable.VerticalFlick
            clip: true

            Column {
                id: settingsColumn
                width: parent.width
                anchors.topMargin: units.gu(2)
                spacing: units.gu(2)

                Column {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: units.gu(1)

                    Label {
                        text: i18n.tr("Server URL")
                        color: "#FFFFFF"
                    }
                    TextField {
                        id: serverUrlField
                        width: parent.width
                        placeholderText: "https://cloud.example.com"
                        inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText
                        text: launchermodular.settings.nextcloudUrl || ""
                        onTextChanged: launchermodular.settings.nextcloudUrl = text
                    }
                }

                Column {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: units.gu(1)

                    Label {
                        text: i18n.tr("Username")
                        color: "#FFFFFF"
                    }
                    TextField {
                        id: usernameField
                        width: parent.width
                        inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                        text: launchermodular.settings.nextcloudUser || ""
                        onTextChanged: launchermodular.settings.nextcloudUser = text
                    }
                }

                Column {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: units.gu(1)

                    Label {
                        text: i18n.tr("App password")
                        color: "#FFFFFF"
                    }
                    TextField {
                        id: appPasswordField
                        width: parent.width
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
                        text: launchermodular.settings.nextcloudPassword || ""
                        onTextChanged: launchermodular.settings.nextcloudPassword = text
                    }
                    Label {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        //fontSize: "x-small"
                        color: "#AEA79F"
                        text: i18n.tr("Use a dedicated app password (Nextcloud Settings → Security → Devices & sessions), not your main account password. It can be revoked independently at any time.")
                    }
                }

                Column {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: units.gu(1)

                    Label {
                        text: i18n.tr("Starting folder")
                        color: "#FFFFFF"
                    }
                    TextField {
                        id: basePathField
                        width: parent.width
                        placeholderText: "/"
                        inputMethodHints: Qt.ImhNoPredictiveText
                        text: launchermodular.settings.nextcloudBasePath || "/"
                        onTextChanged: launchermodular.settings.nextcloudBasePath = text.length > 0 ? text : "/"
                    }
                }

                Row {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: units.gu(1)

                    Button {
                        id: testConnexionButton
                        height: units.gu(4)
                        width: (parent.width/2)-units.gu(2)
                        color: "#0E8420"
                        text: i18n.tr("Test connexion")

                        onClicked: {
                            testConnexion()
                        }
                    }

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#FFFFFF"
                        //width: parent.width
                        wrapMode: Text.WordWrap
                        text: testSucced
                    }
                }

            }
        }

        ActivityIndicator {
            anchors.centerIn: parent
            running: loading
            visible: loading
        }
    }
}
