import QtQuick 2.12
import QtQuick.Layouts 1.12
import Lomiri.Components 1.3

Item {
    id: nextcloudFolders

    property var pageData: ({})

    property string currentPath: pageData.basePath || "/"
    property var pathHistory: []
    property bool loading: false
    property string errorMessage: ""

    Component.onCompleted: {
        if (launchermodular.settings.nextcloudUrl !== '') {
            console.log("load pageData") 
            pageData.username = launchermodular.settings.nextcloudUser
            pageData.appPassword = launchermodular.settings.nextcloudPassword
            pageData.serverUrl = launchermodular.settings.nextcloudUrl
        } else {
            console.log("couldn't load pageData")
        }

        if (configured()) fetchFolder(currentPath)
    }

    function configured() {
        if (pageData) {
            console.log("pageData.serverUrl:" + pageData.serverUrl)
            console.log("pageData.username:" + pageData.username)
        } else {
            console.log("no pageData")
        }
        return pageData.serverUrl && pageData.username && pageData.appPassword
    }

    /**
     * Build webDav URL
     * /remote.php/dav/files/<username>/<chemin>
     */
    function davUrl(path) {
        var base = pageData.serverUrl.replace(/\/+$/, "")
        var cleanPath = path.split("/").map(encodeURIComponent).join("/")
        return base + "/remote.php/dav/files/" + encodeURIComponent(pageData.username) + cleanPath
    }

    function decodeXmlEntities(s) {
        return s.replace(/&amp;/g, "&")
                .replace(/&lt;/g, "<")
                .replace(/&gt;/g, ">")
                .replace(/&quot;/g, "\"")
                .replace(/&#39;/g, "'")
    }

    function expectedSelfPath(path) {
        var cleanPath = path.split("/").map(encodeURIComponent).join("/")
        return "/remote.php/dav/files/" + encodeURIComponent(pageData.username) + cleanPath
    }

    /**
     * Remove th WebDAV prefix (/remote.php/dav/files/<user>)
     **/
    function stripDavPrefix(href) {
        var decoded = decodeURIComponent(href)
        var prefix = "/remote.php/dav/files/" + pageData.username
        var idx = decoded.indexOf(prefix)
        if (idx !== -1) {
            return decoded.substring(idx + prefix.length) || "/"
        }
        return decoded
    }

    /**
     * Extract folder
     **/
    function parseWebDavFolders(xml, requestedPath) {
        var folders = []
        var blocks = xml.split(/<[^:>]*:?response[ >]/i).slice(1)
        var selfPath = expectedSelfPath(requestedPath).replace(/\/+$/, "")

        for (var i = 0; i < blocks.length; i++) {
            var block = blocks[i]
            var isCollection = /<[^:>]*:?collection\s*\/?>/i.test(block)
            if (!isCollection) continue

            var hrefMatch = block.match(/<[^:>]*:?href[^>]*>([^<]*)<\/[^:>]*:?href>/i)
            if (!hrefMatch) continue

            var href = hrefMatch[1]
            var normalizedHref = decodeURIComponent(href).replace(/\/+$/, "")

            // Entrée correspondant au dossier demandé lui-même : pas un enfant, on l'ignore.
            if (normalizedHref === selfPath) continue

            var name = decodeXmlEntities(normalizedHref.split("/").pop())
            if (name.length === 0) continue

            folders.push({ name: name, path: stripDavPrefix(href) })
        }
        return folders
    }

    function fetchFolder(path) {
        loading = true
        console.log("Fetch:" + path)

        var xhr = new XMLHttpRequest()
        xhr.open("PROPFIND", davUrl(path))
        xhr.setRequestHeader("Depth", "1")
        xhr.setRequestHeader("Content-Type", "application/xml; charset=utf-8")
        xhr.setRequestHeader("Authorization", "Basic " + Qt.btoa(pageData.username + ":" + pageData.appPassword))

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            loading = false

            if (xhr.status === 207) {
                var folders = parseWebDavFolders(xhr.responseText, path)
                folderModel.clear()
                for (var i = 0; i < folders.length; i++) {
                    folderModel.append(folders[i])
                }
                currentPath = path
            } else if (xhr.status === 401) {
                errorMessage = i18n.tr("Authentication failed. Check username/app password.")
            } else if (xhr.status === 0) {
                errorMessage = i18n.tr("Network error. Check server URL and connectivity.")
            } else {
                errorMessage = i18n.tr("Error %1 while loading folder.").arg(xhr.status)
            }
        }

        var body = '<?xml version="1.0" encoding="utf-8" ?>' +
                   '<d:propfind xmlns:d="DAV:">' +
                   '<d:prop><d:resourcetype/><d:displayname/></d:prop>' +
                   '</d:propfind>'
        xhr.send(body)
    }

    function openFolder(path) {
        pathHistory.push(currentPath)
        fetchFolder(path)
    }

    function goBack() {
        if (pathHistory.length === 0) return
        var previous = pathHistory.pop()
        fetchFolder(previous)
    }

    ListModel {
        id: folderModel
    }

    Rectangle {
        id: header
        width: parent.width
        height: units.gu(5)
        color: "#111111"

        Icon {
            id: backIcon
            visible: pathHistory.length > 0
            anchors.left: parent.left
            anchors.leftMargin: units.gu(1)
            anchors.verticalCenter: parent.verticalCenter
            height: units.gu(2.5)
            width: height
            name: "back"
            color: "#FFFFFF"

            MouseArea {
                anchors.fill: parent
                anchors.margins: units.gu(-1) // zone de toucher plus large que l'icône
                onClicked: goBack()
            }
        }

        Label {
            anchors.left: backIcon.visible ? backIcon.right : parent.left
            anchors.leftMargin: units.gu(1)
            anchors.right: refreshIcon.left
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideMiddle
            color: "#FFFFFF"
            text: currentPath === "/" || currentPath === "" ? i18n.tr("Nextcloud") : currentPath
        }

        Icon {
            id: refreshIcon
            anchors.right: parent.right
            anchors.rightMargin: units.gu(1)
            anchors.verticalCenter: parent.verticalCenter
            height: units.gu(2.5)
            width: height
            name: "reload"
            color: "#FFFFFF"

            MouseArea {
                anchors.fill: parent
                anchors.margins: units.gu(-1)
                onClicked: fetchFolder(currentPath)
            }
        }
    }

    // Message displayed if not configure
    Column {
        anchors.centerIn: parent
        width: parent.width - units.gu(4)
        visible: !configured()
        spacing: units.gu(1)

        Label {
            width: parent.width
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: "#AEA79F"
            text: i18n.tr("Configure your Nextcloud server in this page's settings first.")
        }
    }

    // Error message
    Label {
        anchors.top: header.bottom
        anchors.topMargin: units.gu(2)
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - units.gu(4)
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        color: "#E95420"
        visible: errorMessage.length > 0
        text: errorMessage
    }

    ActivityIndicator {
        anchors.centerIn: parent
        running: loading
        visible: loading
    }

    ListView {
        id: folderListView
        visible: configured() && !loading && errorMessage.length === 0
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        clip: true
        model: folderModel

        delegate: Rectangle {
            width: folderListView.width
            height: units.gu(6)
            color: "#111111"

            Row {
                anchors.left: parent.left
                anchors.leftMargin: units.gu(1)
                anchors.verticalCenter: parent.verticalCenter
                spacing: units.gu(1)

                Icon {
                    height: units.gu(3)
                    width: height
                    name: "folder-symbolic"
                    color: "#FFFFFF"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#FFFFFF"
                    text: model.name
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: openFolder(model.path)
            }
        }

        Label {
            anchors.centerIn: parent
            visible: folderModel && folderModel.count === 0 && !loading && errorMessage.length === 0 && configured()
            color: "#AEA79F"
            text: i18n.tr("This folder is empty")
        }
    }
}
