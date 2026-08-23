import QtQuick 2.12
import QtQuick.Layouts 1.12
import QtGraphicalEffects 1.12
import Lomiri.Components 1.3
import Qt.labs.folderlistmodel 2.12
import Lomiri.Thumbnailer 0.1
import MySettings 1.0

import QtQuick.Controls 2.2
import Lomiri.Content 1.3

Item {
    id: lomiriFolders

    property string lomiriRootFolder: MySettings.getHomeLocation()
    property var folderNameFilters: ["*"]

    property string searchTerm: ""

    property var folders: []
    property var scannedFolders: []

    property bool initialParsingDone: false
    property bool searchIndexing: false

    property string parentFolder: MySettings.getHomeLocation()
    property string pendingSearch: ""
    property string selectedFilePath: ""

    // ============================================================
    // Search models
    // ============================================================

    ListModel {
        id: searchModel
    }

    ListModel {
        id: searchResults
    }

    // ============================================================
    // Search debounce
    // ============================================================

    Timer {
        id: searchDebounce

        interval: 200
        repeat: false

        onTriggered: {
            searchFile(pendingSearch)
        }
    }

    // ============================================================
    // Timer used when FolderListModel becomes Null
    //
    // A Null status can occur while FolderListModel is changing
    // folder or when a folder cannot be loaded.
    //
    // We wait one Qt event-loop cycle before continuing.
    // ============================================================

    Timer {
        id: nextFolderTimer

        interval: 0
        repeat: false

        onTriggered: {

            if (DEBUG_MODE)
                console.log("### CONTINUE AFTER NULL")

            parseNextFolder()
        }
    }

    Component {
        id: contentItemComponent

        ContentItem {}
    }

    ContentPeerPicker {
        id: exportPeerPicker

        visible: false
        anchors.fill: parent
        z: 10

        handler: ContentHandler.Destination
        contentType: ContentType.All

        onPeerSelected: {

            if (selectedFilePath !== "") {

                var items = []

                items.push(
                    contentItemComponent.createObject(
                        lomiriFolders,
                        {
                            "url": "file://" + selectedFilePath
                        }
                    )
                )

                var transfer = peer.request()

                transfer.items = items
                transfer.state = ContentTransfer.Charged

                exportPeerPicker.visible = false
                selectedFilePath = ""
            }
        }

        onCancelPressed: {
            exportPeerPicker.visible = false
            selectedFilePath = ""
        }
    }

    FolderListModel {
        id: lomiriFileModel

        folder: lomiriRootFolder

        showDotAndDotDot: false
        showDirsFirst: true
        showDirs: true
        showFiles: true

        // nameFilters: folderNameFilters

        rootFolder: lomiriRootFolder

        onFolderChanged: {

            if (!String(folder).startsWith(
                "file://" + lomiriRootFolder)) {

                lomiriFileModel.folder =
                    lomiriRootFolder
            }
        }

        onStatusChanged: {

            if (lomiriFileModel.status ===
                FolderListModel.Ready) {

                initSearchModel()
            }
        }
    }

    FolderListModel {
        id: searchIndexModel

        showDotAndDotDot: false
        showDirs: true
        showFiles: true

        onStatusChanged: {

            if (DEBUG_MODE) {
                console.log(
                    "### STATUS CHANGED:",
                    status,
                    "folder:",
                    folder,
                    "count:",
                    count
                )
            }

            if (status === FolderListModel.Ready) {

                nextFolderTimer.stop()
                resumeNudgeTimer.stop()

                parseForder()

            } else if (status === FolderListModel.Null) {

                if (DEBUG_MODE) {
                    console.log(
                        "### NULL FOLDER, WILL SKIP:",
                        folder
                    )
                }

                nextFolderTimer.restart()
            }
        }
    }

    Timer {
        id: resumeNudgeTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (searchIndexing) {
                if (DEBUG_MODE) {
                    console.log("### INDEX STILL STUCK AFTER RESUME, NUDGING TO NEXT FOLDER")
                }
                parseNextFolder()
            }
        }
    }

    Connections {
        target: Qt.application
        function onStateChanged() {
            if (Qt.application.state === Qt.ApplicationActive && searchIndexing) {
                if (DEBUG_MODE) {
                    console.log("### APP RESUMED WHILE INDEXING, WAITING TO SEE IF IT RECOVERS ON ITS OWN")
                }
                resumeNudgeTimer.restart()
            }
        }
    }

    Component.onCompleted: {

        if (DEBUG_MODE) {
            console.log("############################")
            console.log("### SEARCH COMPONENT START")
            console.log("############################")
            console.log("### ROOT:", lomiriRootFolder)
            console.log(
                "### INDEX FOLDER BEFORE:",
                searchIndexModel.folder
            )
        }

        startSearchIndex()

        if (DEBUG_MODE) {
            console.log(
                "### INDEX FOLDER AFTER:",
                searchIndexModel.folder
            )
        }
    }

    function initSearchModel() {

        searchResults.clear()

        for (var i = 0;
             i < lomiriFileModel.count;
             i++) {

            var filePath =
                lomiriFileModel.get(i, "filePath")

            var fileName =
                lomiriFileModel.get(i, "fileName")

            var fileIsDir =
                lomiriFileModel.get(i, "fileIsDir")

            parentFolder =
                lomiriFileModel.parentFolder

            searchResults.append({
                filePath: filePath,
                fileName: fileName,
                fileIsDir: fileIsDir
            })
        }
    }

    function startSearchIndex() {

        if (searchIndexing) {

            if (DEBUG_MODE)
                console.log(
                    "### INDEX ALREADY RUNNING"
                )

            return
        }

        if (DEBUG_MODE)
            console.log(
                "### START SEARCH INDEX"
            )

        searchModel.clear()

        folders = []
        scannedFolders = []

        initialParsingDone = false
        searchIndexing = true

        /*
         * Start at the root.
         *
         * FolderListModel loads it asynchronously.
         */
        searchIndexModel.folder =
            lomiriRootFolder
    }

    function parseForder() {

        if (searchIndexModel.status !==
            FolderListModel.Ready) {

            if (DEBUG_MODE) {
                console.log(
                    "### parseForder ignored, status:",
                    searchIndexModel.status
                )
            }

            return
        }

        var currentFolder =
            String(searchIndexModel.folder)

        if (DEBUG_MODE) {
            console.log(
                "### PARSE FOLDER:",
                currentFolder,
                "COUNT:",
                searchIndexModel.count
            )
        }

        // Avoid parsing the same folder twice
        if (scannedFolders.indexOf(currentFolder) !== -1) {

            if (DEBUG_MODE) {
                console.log(
                    "### FOLDER ALREADY SCANNED:",
                    currentFolder
                )
            }

            parseNextFolder()
            return
        }

        scannedFolders.push(currentFolder)

        for (var i = 0;
             i < searchIndexModel.count;
             i++) {

            var filePath =
                searchIndexModel.get(i, "filePath")

            var fileName =
                searchIndexModel.get(i, "fileName")

            var fileIsDir =
                searchIndexModel.get(i, "fileIsDir")

            if (fileName &&
                fileName.toLowerCase().indexOf("74c") !== -1) {

                console.log(
                    "### *** FOUND 74C DURING INDEX ***",
                    fileName,
                    filePath
                )
            }

            if (fileIsDir) {

                if (folders.indexOf(filePath) === -1 &&
                    scannedFolders.indexOf(filePath) === -1) {

                    folders.push(filePath)

                    if (DEBUG_MODE) {
                        console.log(
                            "### QUEUE FOLDER:",
                            filePath,
                            "remaining:",
                            folders.length
                        )
                    }
                }

            } else {

                searchModel.append({
                    filePath: filePath,
                    fileName: fileName,
                    fileIsDir: false
                })
            }
        }

        parseNextFolder()
    }

    function parseNextFolder() {

        // --------------------------------------------------------
        // No more folders
        // --------------------------------------------------------

        if (folders.length === 0) {

            searchIndexing = false
            initialParsingDone = true

            if (DEBUG_MODE) {
                console.log(
                    "### SEARCH INDEX COMPLETE",
                    "files:",
                    searchModel.count,
                    "folders:",
                    scannedFolders.length
                )
            }

            if (pendingSearch.length > 0) {

                var searchToExecute =
                    pendingSearch

                pendingSearch = ""

                if (DEBUG_MODE) {
                    console.log(
                        "### EXECUTE PENDING SEARCH:",
                        searchToExecute
                    )
                }

                searchFile(searchToExecute)
            }

            return
        }
        var nextFolder =
            folders.pop()

        if (DEBUG_MODE) {
            console.log(
                "### SCAN NEXT FOLDER:",
                nextFolder,
                "remaining:",
                folders.length
            )
        }

        searchIndexModel.folder =
            nextFolder
    }

    function searchFile(term) {

        console.log(
            "### NEW SEARCH FUNCTION ###",
            term
        )

        searchTerm = term

        if (!term || term.length === 0) {

            searchResults.clear()
            return
        }

        if (!initialParsingDone) {

            pendingSearch = term

            if (DEBUG_MODE) {
                console.log(
                    "### SEARCH ON PARTIAL INDEX:",
                    term,
                    "indexed files so far:",
                    searchModel.count
                )
            }
        }

        var results = []

        var termLower =
            term.toLowerCase()

        if (DEBUG_MODE) {
            console.log(
                "### SEARCH START:",
                term,
                "indexed files:",
                searchModel.count
            )
        }

        for (var i = 0;
             i < searchModel.count;
             i++) {

            var item =
                searchModel.get(i)

            if (!item.fileName)
                continue

            var fileNameLower =
                item.fileName.toLowerCase()

            if (fileNameLower.indexOf(termLower) !== -1) {

                if (DEBUG_MODE) {
                    console.log(
                        "### SEARCH MATCH:",
                        item.fileName,
                        item.filePath
                    )
                }

                results.push({
                    filePath: item.filePath,
                    fileName: item.fileName,
                    fileIsDir: item.fileIsDir
                })
            }
        }

        searchResults.clear()

        for (var j = 0;
             j < results.length;
             j++) {

            searchResults.append(
                results[j]
            )
        }

        if (DEBUG_MODE) {
            console.log(
                "### SEARCH COMPLETE:",
                term,
                "results:",
                results.length
            )
        }
    }

    Rectangle {
        id: searchBar

        height: units.gu(5)
        width: parent.width

        color: "transparent"

        Rectangle {
            id: searchFileBackground

            color:
                launchermodular.settings.backgroundColor

            radius: units.gu(1)

            opacity: 0.3

            anchors.fill: parent
        }

        Icon {
            id: iconBack

            visible:
                lomiriFileModel.folder !=
                "file://" + lomiriRootFolder &&
                searchField.text.length === 0

            anchors {
                left: searchBar.left

                rightMargin:
                    units.gu(
                        launchermodular.settings.folderFontSize
                    )

                leftMargin:
                    units.gu(
                        launchermodular.settings.folderFontSize
                    )

                verticalCenter:
                    parent.verticalCenter
            }

            height:
                parent.height * 0.5

            width:
                height

            name: "revert"

            MouseArea {
                anchors.fill: parent

                onClicked: {
                    lomiriFileModel.folder =
                        lomiriFileModel.parentFolder
                }
            }
        }

        TextField {
            id: searchField

            focus: false

            anchors {
                left: iconBack.right
                right: iconSearch.left
            }

            height:
                searchBar.height

            color:
                launchermodular.settings.textColor

            background: Rectangle {
                height:
                    parent.height

                color:
                    "transparent"
            }

            placeholderText: ""

            Text {
                anchors.fill: parent

                anchors.leftMargin:
                    units.gu(2)

                verticalAlignment:
                    Text.AlignVCenter

                color:
                    "#aaaaaa"

                text:
                    i18n.tr("Search a file")

                visible:
                    searchField.text.length === 0

                font.pixelSize:
                    units.gu(
                        launchermodular.settings.folderFontSize
                    )
            }

            inputMethodHints:
                Qt.ImhNoPredictiveText

            onTextChanged: {

                if (text.length > 0) {

                    pendingSearch = text

                    searchDebounce.restart()

                } else {

                    pendingSearch = ""

                    searchDebounce.stop()

                    searchResults.clear()

                    if (lomiriFileModel.folder ===
                        "file://" + lomiriRootFolder) {

                        lomiriFileModel.folder = ""
                    }

                    lomiriFileModel.folder =
                        lomiriRootFolder
                }
            }
        }

        Icon {
            id: iconSearch

            anchors {
                right:
                    searchBar.right

                rightMargin:
                    units.gu(1)

                leftMargin:
                    units.gu(1)

                verticalCenter:
                    parent.verticalCenter
            }

            height:
                parent.height * 0.5

            width:
                height

            name: {
                if (searchField.text.length > 0)
                    return "edit-clear"

                return "find"
            }

            MouseArea {
                anchors.fill: parent

                onClicked: {

                    if (searchField.text.length > 0) {
                        searchField.text = ""
                        initSearchModel()
                    } else if (
                        lomiriFileModel.folder ===
                        "file://" + lomiriRootFolder
                    ) {

                        lomiriFileModel.folder = ""
                    }

                    lomiriFileModel.folder =
                        lomiriRootFolder
                }
            }
        }
    }

    // Search results ListView
    ListView {
        id: searchFileView

        model:
            searchResults

        width:
            parent.width

        anchors {
            fill: parent

            rightMargin:
                units.gu(2)

            leftMargin:
                units.gu(2)

            topMargin:
                units.gu(6)
        }

        clip: true

        focus: true

        delegate: Item {

            width:
                searchFileView.cellWidth

            height:
                searchFileViewName.implicitHeight

            Rectangle {
                id: searchFileRectangle

                opacity:
                    0.9

                color:
                    "#111111"

                height:
                    searchFileViewName.implicitHeight

                width:
                    parent.width

                Row {

                    spacing:
                        units.gu(1)

                    Icon {
                        id: searchFileViewItem

                        visible: true

                        height:
                            units.gu(
                                launchermodular.settings.folderFontSize
                            )

                        width:
                            units.gu(
                                launchermodular.settings.folderFontSize
                            )

                        name:
                            fileIsDir
                                ? "folder-symbolic"
                                : "text-x-generic-symbolic"

                        color:
                            launchermodular.settings.folderFontColor
                    }

                    Text {
                        id: searchFileViewName

                        text:
                            fileName

                        font.pixelSize:
                            units.gu(
                                launchermodular.settings.folderFontSize
                            )

                        color:
                            launchermodular.settings.folderFontColor

                        MouseArea {
                            anchors.fill: parent

                            onClicked: {

                                if (!fileIsDir) {

                                    selectedFilePath =
                                        model.filePath

                                    exportPeerPicker.visible =
                                        true

                                } else {

                                    searchTerm = ""

                                    lomiriFileModel.folder =
                                        model.filePath
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
