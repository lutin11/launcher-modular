import QtQuick 2.12
import QtQuick.Controls 2.2
import Qt.labs.settings 1.0
import Qt.labs.folderlistmodel 2.12
import Lomiri.Components 1.3
import Lomiri.Components.ListItems 1.3 as ListItemHeader
import Lomiri.Components.Themes 1.3
import QtQuick.Layouts 1.12

// Settings of one "Nextcloud folders" page.
//
// The account is stored in the page data (pageIndex, injected by
// Pagemanagement), so two folder pages can use two different accounts. The
// global settings are only a fallback: a page without its own account keeps
// the historic behaviour.
Page {
    id: pageSettingsNextcloudFolders

    property string nextcloudPageName: i18n.tr("nextcloudFolders") // do not remove, use pour Po files
    property int pageIndex: -1
    // Stable page identifier (injected by Pagemanagement).
    property string pageUid: ""
    property string pageName: ""

    property string testSucced: i18n.tr("Test it !")
    property bool loading: false
    property string errorMessage: ""

    function pageConfig() {
        if (pageUid.length > 0) {
            var stored = launchermodular.getPageConfig(pageUid)
            if (stored && typeof stored === "object")
                return stored
        }
        // Legacy: pages created before the uid stored their account here.
        if (pageIndex >= 0 && pageIndex < launchermodular.pageModel.count) {
            var data = launchermodular.pageModel.get(pageIndex).data
            if (data && typeof data === "object")
                return data
        }
        return ({})
    }

    function loadConfig() {
        var config = pageConfig()
        serverUrlField.text = config.nextcloudUrl || launchermodular.settings.nextcloudUrl || ""
        usernameField.text = config.nextcloudUser || launchermodular.settings.nextcloudUser || ""
        appPasswordField.text = config.nextcloudPassword || launchermodular.settings.nextcloudPassword || ""
        basePathField.text = config.nextcloudBasePath || launchermodular.settings.nextcloudBasePath || "/"
    }

    // Without a page context (never reached from Pagemanagement) the global
    // settings are updated, as before.
    function saveConfig() {
        var config = {
            "nextcloudUrl": serverUrlField.text,
            "nextcloudUser": usernameField.text,
            "nextcloudPassword": appPasswordField.text,
            "nextcloudBasePath": basePathField.text.length > 0 ? basePathField.text : "/"
        }
        if (pageUid.length > 0) {
            launchermodular.setPageConfig(pageUid, config)
            // Legacy copy, for builds reading the page data.
            if (pageIndex >= 0 && pageIndex < launchermodular.pageModel.count)
                launchermodular.pageModel.setProperty(pageIndex, "data", config)
        } else if (pageIndex >= 0 && pageIndex < launchermodular.pageModel.count) {
            launchermodular.pageModel.setProperty(pageIndex, "data", config)
        } else {
            launchermodular.settings.nextcloudUrl = serverUrlField.text
            launchermodular.settings.nextcloudUser = usernameField.text
            launchermodular.settings.nextcloudPassword = appPasswordField.text
            launchermodular.settings.nextcloudBasePath = basePathField.text.length > 0 ? basePathField.text : "/"
        }
    }

    Component.onCompleted: loadConfig()

    function davUrl() {
        var base = serverUrlField.text.replace(/\/+$/, "")
        return base + "/remote.php/dav/files/" + encodeURIComponent(usernameField.text) + "/"
    }

    function testConnexion() {
        loading = true
        testSucced = ""
        errorMessage = ""

        var xhr = new XMLHttpRequest()
        xhr.open("PROPFIND", davUrl())
        xhr.setRequestHeader("Depth", "1")
        xhr.setRequestHeader("Content-Type", "application/xml; charset=utf-8")
        xhr.setRequestHeader("Authorization", "Basic " + Qt.btoa(usernameField.text + ":" + appPasswordField.text))

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
                if (DEBUG_MODE) console.log(errorMessage)
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
                onTriggered: {
                    pageSettingsNextcloudFolders.saveConfig()
                    pageStack.pop()
                }
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
                    }
                    Label {
                        width: parent.width
                        wrapMode: Text.WordWrap
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
                        text: i18n.tr("Save and test")
                        onClicked: {
                            pageSettingsNextcloudFolders.saveConfig()
                            pageSettingsNextcloudFolders.testConnexion()
                        }
                    }

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#FFFFFF"
                        width: parent.width / 2
                        wrapMode: Text.WordWrap
                        text: pageSettingsNextcloudFolders.errorMessage.length > 0
                              ? pageSettingsNextcloudFolders.errorMessage
                              : pageSettingsNextcloudFolders.testSucced
                    }
                }
            }
        }

        ActivityIndicator {
            anchors.centerIn: parent
            running: pageSettingsNextcloudFolders.loading
            visible: pageSettingsNextcloudFolders.loading
        }
    }
}
