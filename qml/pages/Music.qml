import QtQuick 2.12
import QtQuick.Layouts 1.12
import QtGraphicalEffects 1.12
import Lomiri.Components 1.3
import Qt.labs.folderlistmodel 2.12
import Lomiri.Thumbnailer 0.1
import MySettings 1.0
import QtSystemInfo 5.0 // for screen saver

Item {
    id: musics

    property string rootMusic: MySettings.getMusicLocation()
    property var musicNameFilters: ["*.mp3", "*.aac", "*.ogg", "*.wav", "*.flac", "*.m4a", "*.alac"]
    property string searchTerm: ""
    property var folders: []
    property bool initialParsingDone: false
    property string parentFolder: MySettings.getMusicLocation()
    property string pendingSearch: ""
    readonly property bool selectionMode: musicPlayer.playlist.length > 0
    property bool showingPlaylists: false

    ScreenSaver {
        id: screenSaver
        screenSaverEnabled: true
    }

    // Components
    PlaylistManager { id: playlistManager }
    MusicPlayer {
        id: musicPlayer
        showingPlaylists: musics.showingPlaylists
        onShowPlaylists: musics.showingPlaylists = true
        onHidePlaylists: musics.showingPlaylists = false
        onStateChanged: {
            screenSaver.screenSaverEnabled = (newState !== MusicPlayer.Playing)
        }
    }

    Component.onCompleted: {
        musicPlayer.visible = true
        musicPlayer.cleanupCache()
    }

    function toggleSelection(filePath, fileName) {
        if (isSelected(filePath)) {
            musicPlayer.removeFromPlaylist(filePath, fileName)
        } else {
            musicPlayer.addToPlaylist(filePath, fileName)
        }
    }
    Check if a file is selected
    function isSelected(filePath) {
        var playlist = musicPlayer.playlist
        for (var i = 0; i < playlist.length; i++) {
            if (playlist[i].path === filePath) return true
        }
        return false
    }

    /**
     * Select all music files in current view
     */
    function selectAll() {
        var songs = []
        for (var i = 0; i < searchResults.count; i++) {
            var item = searchResults.get(i)
            if (!item.fileIsDir) {
                songs.push({path: item.filePath, name: item.fileName})
            }
        }
        musicPlayer.playList(songs)
    }

    /**
     * Deselect all files
     */
    function deselectAll() {
        musicPlayer.clear()
    }

    function hasSongsInView() {
        for (var i = 0; i < searchResults.count; i++) {
            if (!searchResults.get(i).fileIsDir) return true
        }
        return false
    }

    function isAllSelected() {
        var anySong = false
        for (var i = 0; i < searchResults.count; i++) {
            var item = searchResults.get(i)
            if (!item.fileIsDir) {
                anySong = true
                if (!isSelected(item.filePath)) return false
            }
        }
        return anySong
    }

    function toggleSelectAll() {
        if (isAllSelected()) {
            deselectAll()
        } else {
            selectAll()
        }
    }

    ListModel {
        id: searchModel
    }

    ListModel {
        id: searchResults
    }

    Timer {
        id: searchDebounce
        interval: 200
        repeat: false
        onTriggered: searchMusic(pendingSearch)
    }

    FolderListModel {
        id: musicFileModel
        folder: rootMusic
        showDotAndDotDot: false
        showDirsFirst: true
        showDirs: true
        showFiles: true
        nameFilters: musicNameFilters
        rootFolder: rootMusic

        onFolderChanged: {
            if (!String(folder).startsWith("file://" + rootMusic)) {
                musicFileModel.folder = rootMusic; // Revenir à la racine
            } else {
                musicFileModel.folder = folder
            }
        }
        onStatusChanged: if (musicFileModel.status == FolderListModel.Ready) {
            if (!initialParsingDone) {
                parseForder()
            } else {
                initSearchModel()
            }
        }
    }

    function initSearchModel() {
        searchResults.clear()
        for (var i = 0; i < musicFileModel.count; i++) {
            let filePath = musicFileModel.get(i, "filePath")
            let fileName = musicFileModel.get(i, "fileName")
            let fileIsDir = musicFileModel.get(i, "fileIsDir")
            parentFolder = musicFileModel.parentFolder
            searchResults.append({filePath : filePath, fileName : fileName, fileIsDir: fileIsDir});
        }
    }

    function parseForder() {
        for (var i = 0; i < musicFileModel.count; i++) {
            let filePath = musicFileModel.get(i, "filePath")
            let fileName = musicFileModel.get(i, "fileName")
            let fileIsDir = musicFileModel.get(i, "fileIsDir")

            if (!fileIsDir) {
                searchModel.append({filePath : filePath, fileName : fileName, fileIsDir: fileIsDir});
            } else {
                folders.push(filePath)
            }
        }
        parseNextFolder()
    }

    function parseNextFolder() {
        if(folders.length > 0) {
            let aFolder = folders.pop();
            musicFileModel.folder = aFolder;
        } else {
            initialParsingDone = true;
            musicFileModel.folder = rootMusic;
            if (DEBUG_MODE) console.log("searching model complet")
        }
    }

    function searchMusic(term) {
        if (DEBUG_MODE) console.log("searchMusic with term:" + term)
        searchTerm = term
        var results = []
        var termLower = term.toLowerCase()
        for (var i = 0; i < searchModel.count; i++) {
            var item = searchModel.get(i);
            if (item.fileName.toLowerCase().indexOf(termLower) !== -1) {
                results.push({filePath: item.filePath, fileName: item.fileName, fileIsDir: item.fileIsDir});
            }
        }
        searchResults.clear()
        for (var j = 0; j < results.length; j++) {
            searchResults.append(results[j]);
        }
    }

    // Search bar
    Rectangle {
        id: searchBar
        height: units.gu(5)
        width: parent.width
        color: "transparent"

        Rectangle {
            id: searchMusicBackground
            color: launchermodular.settings.backgroundColor
            radius: units.gu(1)
            opacity: 0.3
            anchors.fill: parent
        }

        Icon {
            id: iconBack
            visible: musicFileModel.folder != "file://" + rootMusic && searchField.text.length === 0
            anchors {
                left: searchBar.left
                rightMargin: units.gu(launchermodular.settings.musicFontSize)
                leftMargin: units.gu(launchermodular.settings.musicFontSize)
                verticalCenter: parent.verticalCenter
            }
            height: parent.height*0.5
            width: height
            name: "revert"

            MouseArea {
                anchors.fill: parent
                onClicked:{
                    musicFileModel.folder = musicFileModel.parentFolder
                }
            }
        }

        Item {
            id: searchField
            anchors {
                left: iconBack.right
                right: iconSearch.left
            }
            height: searchBar.height

            property alias text: searchInput.text

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: units.gu(1)
                verticalAlignment: TextInput.AlignVCenter
                color: launchermodular.settings.textColor
                clip: true
                selectByMouse: true
                inputMethodHints: Qt.ImhNoPredictiveText

                onTextChanged: {
                    if(text.length > 0) {
                        pendingSearch = text
                        searchDebounce.restart()
                    } else {
                        searchDebounce.stop()
                        searchResults.clear()
                        if(musicFileModel.folder == "file://" + rootMusic) {
                            musicFileModel.folder = ""; // force refresh
                        }
                        musicFileModel.folder = rootMusic
                    }
                }
            }

            // Custom placeholder
            Text {
                anchors.fill: parent
                anchors.leftMargin: units.gu(2)
                verticalAlignment: Text.AlignVCenter
                color: "#aaaaaa" // Light grey color for placeholder
                text: i18n.tr("Search your music")
                visible: searchInput.text.length == 0
                font.pixelSize: units.gu(launchermodular.settings.musicFontSize)
            }
        }

        Icon {
            id: iconSearch
            anchors {
                right: searchBar.right
                rightMargin: units.gu(1)
                leftMargin: units.gu(1)
                verticalCenter: parent.verticalCenter
            }
            height: parent.height*0.5
            width: height
            name: {
                if (searchField.text.length > 0) {
                    "edit-clear"
                } else {
                    "find"
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked:{
                    if(searchField.text.length > 0){
                        searchField.text = ""
                        searchInput.focus = false
                    } else if(musicFileModel.folder == "file://" + rootMusic) {
                        musicFileModel.folder = ""; // force refresh
                    }
                    musicFileModel.folder = rootMusic
                }
            }
        }
    }

    // Song list
    ListView {
        id: searchMusicView
        model: searchResults
        visible: !showingPlaylists

        width: parent.width
        anchors {
            fill: parent
            rightMargin: units.gu(2)
            leftMargin: units.gu(2)
            topMargin: units.gu(6)
            bottomMargin: units.gu(16) // leave space for player
        }
        clip: true  // To avoid rendering content outside of the visible area

        focus: true

        header: Rectangle {
            width: searchMusicView.width
            height: hasSongsInView() ? units.gu(5) : 0
            visible: hasSongsInView()
            color: "transparent"

            Row {
                spacing: units.gu(1)
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: units.gu(1)

                Rectangle {
                    width: units.gu(2)
                    height: units.gu(2)
                    radius: units.gu(0.5)
                    color: isAllSelected() ? "#E95420" : "transparent"
                    border.color: "#FFFFFF"
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "\u2713"
                        color: "#FFFFFF"
                        visible: isAllSelected()
                        font.pixelSize: units.gu(1.5)
                    }
                }

                Text {
                    text: isAllSelected() ? i18n.tr("Deselect all") : i18n.tr("Select all")
                    color: launchermodular.settings.musicFontColor
                    font.pixelSize: units.gu(launchermodular.settings.musicFontSize)
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: toggleSelectAll()
            }
        }

        delegate: Item {
            width: searchMusicView.width
            height: searchMusicViewName.implicitHeight + units.gu(2)

            Rectangle {
                id: searchMusicRectangle
                opacity: 0.9
                color: !fileIsDir && isSelected(filePath) ? "#333333" : "#111111"
                height: parent.height
                width: parent.width

                Row {
                    spacing: units.gu(1)
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: units.gu(1)

                    // Selection checkbox
                    Rectangle {
                        width: units.gu(2)
                        height: units.gu(2)
                        radius: units.gu(0.5)
                        color: !fileIsDir && isSelected(filePath) ? "#E95420" : "transparent"
                        border.color: "#FFFFFF"
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !fileIsDir

                        Text {
                            anchors.centerIn: parent
                            text: "\u2713"
                            color: "#FFFFFF"
                            visible: !fileIsDir && isSelected(filePath)
                            font.pixelSize: units.gu(1.5)
                        }
                    }

                    Icon {
                        id: searchMusicViewItem
                        visible: true
                        height: units.gu(launchermodular.settings.musicFontSize)
                        width: units.gu(launchermodular.settings.musicFontSize)
                        name: fileIsDir ? "folder-symbolic" : "stock_music"
                        color: launchermodular.settings.musicFontColor
                    }
                    Text {
                        id: searchMusicViewName
                        text: fileName
                        font.pixelSize: units.gu(launchermodular.settings.musicFontSize)
                        font.bold: fileIsDir ? true : false
                        color: launchermodular.settings.musicFontColor
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (fileIsDir) {
                            searchTerm = ""
                            musicFileModel.folder = model.filePath
                        } else {
                            toggleSelection(model.filePath, model.fileName)
                        }
                    }
                }
            } // Item
        }// delegate Rectangle
    }

    // Playlists list — remplace song lists
    PlaylistsView {
        id: playlistsView
        visible: showingPlaylists
        anchors {
            fill: parent
            rightMargin: units.gu(2)
            leftMargin: units.gu(2)
            topMargin: units.gu(6)
            bottomMargin: units.gu(16) // leave space for player
        }
        playlistManager: playlistManager
        musicPlayer: musicPlayer
    }
}
