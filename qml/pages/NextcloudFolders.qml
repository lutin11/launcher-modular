import QtQuick 2.12
import QtQuick.Layouts 1.12
import Lomiri.Components 1.3
import Lomiri.Content 1.3
import MySettings 1.0
import Lomiri.DownloadManager 1.2
import Terminalaccess 1.0

Item {
    id: nextcloudFolders

    // Not used, but for compatibility with the one injected from Main.qml
    property var pageData: ({})

    property string currentPath: launchermodular.settings.nextcloudBasePath || "/"
    property var pathHistory: []
    property bool loading: false
    property string errorMessage: ""
    property var selectedFiles: []
    property string downloadMessage: ""
    property var pendingDownloadedFiles: []   // {name, localPath} déjà téléchargés, en attente d'export

    readonly property string downloadCacheDir: MySettings.getHomeLocation() + "/.cache/launchermodular.lut11/nextcloud-downloads/"

    onVisibleChanged: {
        if (visible && configured()) {
            fetchFolder(currentPath)
        }
    }

    Component.onCompleted: {
        Terminalaccess.makePath(downloadCacheDir)
    }

    function configured() {
        return !!(launchermodular.settings.nextcloudUrl && launchermodular.settings.nextcloudUser && launchermodular.settings.nextcloudPassword)
    }

    /**
     * Build webDav URL
     * /remote.php/dav/files/<username>/<chemin>
     */
    function davUrl(path) {
        var base = launchermodular.settings.nextcloudUrl.replace(/\/+$/, "")
        var cleanPath = path.split("/").map(encodeURIComponent).join("/")
        return base + "/remote.php/dav/files/" + encodeURIComponent(launchermodular.settings.nextcloudUser) + cleanPath
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
        return "/remote.php/dav/files/" + encodeURIComponent(launchermodular.settings.nextcloudUser) + cleanPath
    }

    /**
     * Remove th WebDAV prefix (/remote.php/dav/files/<user>)
     **/
    function stripDavPrefix(href) {
        var decoded = decodeURIComponent(href)
        var prefix = "/remote.php/dav/files/" + launchermodular.settings.nextcloudUser
        var idx = decoded.indexOf(prefix)
        if (idx !== -1) {
            return decoded.substring(idx + prefix.length) || "/"
        }
        return decoded
    }

    /**
     * Extract folder
     **/
    function parseWebDavEntries(xml, requestedPath) {
        var entries = []
        var blocks = xml.split(/<[^:>]*:?response[ >]/i).slice(1)
        var selfPath = expectedSelfPath(requestedPath).replace(/\/+$/, "")

        for (var i = 1; i < blocks.length; i++) {
            var block = blocks[i]
            var isCollection = /<[^:>]*:?collection\s*\/?>/i.test(block)
            //if (!isCollection) continue

            var hrefMatch = block.match(/<[^:>]*:?href[^>]*>([^<]*)<\/[^:>]*:?href>/i)
            if (!hrefMatch) continue

            var href = hrefMatch[1]
            var normalizedHref = decodeURIComponent(href).replace(/\/+$/, "")

            // Entrée correspondant au dossier demandé lui-même : pas un enfant, on l'ignore.
            if (normalizedHref === selfPath) continue
            var name = decodeXmlEntities(normalizedHref.split("/").pop())
            if (name.length === 0) continue
            var hrefPath = stripDavPrefix(href)
            entries.push({ name: name, path: hrefPath, isFolder: isCollection })
        }
        // Folder first, then ordered files
        entries.sort(function(a, b) {
            if (a.isFolder !== b.isFolder) return a.isFolder ? -1 : 1
            return a.name.localeCompare(b.name)
        })
        return entries
    }

    function fetchFolder(path) {
        loading = true

        var xhr = new XMLHttpRequest()
        xhr.open("PROPFIND", davUrl(path))
        xhr.setRequestHeader("Depth", "1")
        xhr.setRequestHeader("Content-Type", "application/xml; charset=utf-8")
        xhr.setRequestHeader("Authorization", "Basic " + Qt.btoa(launchermodular.settings.nextcloudUser + ":" + launchermodular.settings.nextcloudPassword))

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            loading = false

            if (xhr.status === 207) {
                var entries = parseWebDavEntries(xhr.responseText, path)
                folderModel.clear()
                for (var i = 0; i < entries.length; i++) {
                    folderModel.append(entries[i])
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
        // use slice() to force UI refresh
        var newHistory = pathHistory.slice()
        if (path && currentPath !== path) {
            newHistory.push(currentPath)
            pathHistory = newHistory // réassignation -> déclenche pathHistoryChanged
            fetchFolder(path)
        }
    }

    function goBack() {
        if (pathHistory.length === 0) return
        // use slice() to force UI refresh
        var newHistory = pathHistory.slice()
        var previous = newHistory.pop()
        pathHistory = newHistory // réassignation -> déclenche pathHistoryChanged
        fetchFolder(previous)
    }

    function isFileSelected(path) {
        for (var i = 0; i < selectedFiles.length; i++) {
            if (selectedFiles[i].path === path) return true
        }
        return false
    }

    function toggleFileSelection(name, path) {
        var idx = -1
        for (var i = 0; i < selectedFiles.length; i++) {
            if (selectedFiles[i].path === path) { idx = i; break }
        }
        var newSelection = selectedFiles.slice()
        if (idx !== -1) {
            newSelection.splice(idx, 1)
        } else {
            newSelection.push({ name: name, path: path })
        }
        selectedFiles = newSelection // réassignation -> déclenche selectedFilesChanged
    }

    function shellEscape(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'"
    }

    DownloadManager {
        id: manager
    }

    function downloadSelectedFiles() {
        if (selectedFiles.length === 0) return
        var queue = selectedFiles.slice()
        pendingDownloadedFiles = []
        downloadMessagedownloadMessagedownloadMessage = i18n.tr("Downloading 1/%1...").arg(queue.length)
        downloadNextFile(queue, 0)
    }

    function downloadNextFile(queue, index) {
        if (index >= queue.length) {
            downloadMessage = ""
            if (pendingDownloadedFiles.length > 0) {
                exportPeerPicker.visible = true
            }
            return
        }
        loading = true
        var file = queue[index]
        var xhr = new XMLHttpRequest()
        xhr.open("GET", davUrl(file.path))
        xhr.responseType = "arraybuffer"
        xhr.setRequestHeader("Authorization", "Basic " + Qt.btoa(launchermodular.settings.nextcloudUser + ":" + launchermodular.settings.nextcloudPassword))

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return

            if (xhr.status === 200) {
                var cachePath = downloadCacheDir + file.name
                if (Terminalaccess.writeBytes(cachePath, xhr.response)) {
                    var updated = pendingDownloadedFiles.slice()
                    updated.push({ name: file.name, localPath: cachePath })
                    pendingDownloadedFiles = updated
                } else {
                    errorMessage = i18n.tr("Failed to save %1 locally.").arg(file.name)
                }
            } else {
                errorMessage = i18n.tr("Failed to download %1 (error %2).").arg(file.name).arg(xhr.status)
            }

            downloadMessage = i18n.tr("Downloading %1/%2...").arg(index + 2).arg(queue.length)
            downloadNextFile(queue, index + 1)
        }
        xhr.send()
    }

    ListModel {
        id: folderModel
    }

    Component {
        id: contentItemComponent
        ContentItem {}
    }

    // Display ("Send to...")
    ContentPeerPicker {
        id: exportPeerPicker
        visible: false
        anchors.fill: parent
        z: 10
        handler: ContentHandler.Destination
        contentType: ContentType.All

        onPeerSelected: {
            var items = []
            for (var i = 0; i < pendingDownloadedFiles.length; i++) {
                items.push(contentItemComponent.createObject(nextcloudFolders, {
                    "url": "file://" + pendingDownloadedFiles[i].localPath
                }))
            }
            var transfer = peer.request()
            transfer.items = items
            transfer.state = ContentTransfer.Charged
            exportPeerPicker.visible = false
            pendingDownloadedFiles = []
            loading = false
            selectedFiles = []
        }

        onCancelPressed: {
            exportPeerPicker.visible = false
            pendingDownloadedFiles = []
            loading = false
            selectedFiles = []
        }
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
            name: "go-previous" //"back"
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
            anchors.right: downloadIcon.visible ? downloadIcon.left : refreshIcon.left
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideMiddle
            color: "#FFFFFF"
            text: currentPath === "/" || currentPath === "" ? i18n.tr("Nextcloud") : currentPath
        }

        Icon {
            id: downloadIcon
            visible: selectedFiles.length > 0
            anchors.right: refreshIcon.left
            anchors.rightMargin: units.gu(1)
            anchors.verticalCenter: parent.verticalCenter
            height: units.gu(2.5)
            width: height
            name: "save"
            color: "#E95420"

            MouseArea {
                anchors.fill: parent
                anchors.margins: units.gu(-1)
                onClicked: downloadSelectedFiles()
            }
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
                onClicked: {
                    loading = false
                    selectedFiles = []
                    fetchFolder(currentPath)
                }
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

    // Confirm download
    Label {
        anchors.top: header.bottom
        anchors.topMargin: units.gu(1)
        anchors.horizontalCenter: parent.horizontalCenter
        color: "#AEA79F"
        visible: downloadMessage.length > 0
        text: downloadMessage

        Timer {
            interval: 3000
            running: downloadMessage.length > 0
            onTriggered: downloadMessage = ""
        }
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
            color: !model.isFolder && isFileSelected(model.path) ? "#333333" : "#111111"

            Row {
                anchors.left: parent.left
                anchors.leftMargin: units.gu(1)
                anchors.verticalCenter: parent.verticalCenter
                spacing: units.gu(1)

                Rectangle {
                    width: units.gu(2)
                    height: units.gu(2)
                    radius: units.gu(0.5)
                    visible: !model.isFolder
                    color: !model.isFolder && isFileSelected(model.path) ? "#E95420" : "transparent"
                    border.color: "#FFFFFF"
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter

                    Label {
                        anchors.centerIn: parent
                        text: "\u2713"
                        color: "#FFFFFF"
                        visible: !model.isFolder && isFileSelected(model.path)
                        fontSize: "x-small"
                    }
                }

                Icon {
                    height: units.gu(3)
                    width: height
                    name: model.isFolder ? "folder-symbolic" : "text-x-generic-symbolic"
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
                onClicked: {
                    if (model.isFolder) {
                        openFolder(model.path)
                    } else {
                        toggleFileSelection(model.name, model.path)
                    }
                }
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
