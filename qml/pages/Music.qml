import QtQuick 2.12
import QtQuick.Layouts 1.12
import QtGraphicalEffects 1.12
import Lomiri.Components 1.3
import Qt.labs.folderlistmodel 2.12
import Lomiri.Thumbnailer 0.1
import MySettings 1.0
import QtQuick.Controls 2.2
import Lomiri.Components.Popups 1.3

Item {
    id: musics

    property string rootMusic: MySettings.getMusicLocation()
    property var musicNameFilters: ["*.mp3", "*.aac", "*.ogg", "*.wav", "*.flac", "*.m4a", "*.alac"]
    property string searchTerm: ""
    property var folders: []
    property bool initialParsingDone: false
    property string parentFolder: MySettings.getMusicLocation()
    property string pendingSearch: ""
    property var selectedSongs: []
    property bool selectionMode: false

    // Components
    Playlists { id: playlists }
    MusicPlayer { id: musicPlayer }

    ListModel { id: searchModel }
    ListModel { id: searchResults }

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
                musicFileModel.folder = rootMusic;
            } else {
                musicFileModel.folder = folder
            }
        }
        onStatusChanged: if (musicFileModel.status == FolderListModel.Ready) {
            if (!initialParsingDone) {
                parseFolder()
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

    function parseFolder() {
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
        }
    }

    function searchMusic(term) {
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

    function toggleSelection(filePath, fileName) {
        var idx = -1
        for (var i = 0; i < selectedSongs.length; i++) {
            if (selectedSongs[i].path === filePath) {
                idx = i
                break
            }
        }
        if (idx !== -1) {
            selectedSongs.splice(idx, 1)
        } else {
            selectedSongs.push({path: filePath, name: fileName})
        }
        selectedSongsChanged()
        selectionMode = selectedSongs.length > 0
    }

    function isSelected(filePath) {
        for (var i = 0; i < selectedSongs.length; i++) {
            if (selectedSongs[i].path === filePath) return true
        }
        return false
    }

    function playSelected() {
        if (selectedSongs.length > 0) {
            musicPlayer.playList(selectedSongs)
        }
    }

    function saveSelectedAsPlaylist() {
        PopupUtils.open(savePlaylistDialog)
    }

    function selectAll() {
        selectedSongs = []
        for (var i = 0; i < searchResults.count; i++) {
            var item = searchResults.get(i)
            if (!item.fileIsDir) {
                selectedSongs.push({path: item.filePath, name: item.fileName})
            }
        }
        selectedSongsChanged()
        selectionMode = selectedSongs.length > 0
    }

    function deselectAll() {
        selectedSongs = []
        selectedSongsChanged()
        selectionMode = false
    }

    Component {
        id: savePlaylistDialog
        Dialog {
            id: saveDialog
            title: i18n.tr("Save Playlist")
            TextField {
                id: playlistNameField
                placeholderText: i18n.tr("Playlist name")
                width: parent.width
            }
            Row {
                width: parent.width
                spacing: units.gu(1)
                Button {
                    text: i18n.tr("Save")
                    color: "#0E8420"
                    width: parent.width / 2
                    onClicked: {
                        if (playlistNameField.text.length > 0) {
                            playlists.savePlaylist(playlistNameField.text, selectedSongs)
                            var names = launchermodular.settings.playlistNames || []
                            if (names.indexOf(playlistNameField.text) === -1) {
                                names.push(playlistNameField.text)
                                launchermodular.settings.playlistNames = names
                            }
                            PopupUtils.close(saveDialog)
                        }
                    }
                }
                Button {
                    text: i18n.tr("Cancel")
                    width: parent.width / 2
                    onClicked: PopupUtils.close(saveDialog)
                }
            }
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
                onClicked: musicFileModel.folder = musicFileModel.parentFolder
            }
        }

        TextField {
            id: searchField
            focus: false
            anchors {
                left: iconBack.right
                right: iconSearch.left
            }
            height: searchBar.height
            color: launchermodular.settings.textColor
            background: Rectangle { height: parent.height; color: "transparent" }
            placeholderText: ""
            Text {
                anchors.fill: parent
                anchors.leftMargin: units.gu(2)
                verticalAlignment: Text.AlignVCenter
                color: "#aaaaaa"
                text: i18n.tr("Search your music")
                visible: searchField.text.length == 0
                font.pixelSize: units.gu(launchermodular.settings.musicFontSize)
            }
            inputMethodHints: Qt.ImhNoPredictiveText
            onTextChanged: {
                if(text.length > 0) {
                    pendingSearch = text
                    searchDebounce.restart()
                } else {
                    searchDebounce.stop()
                    searchResults.clear()
                    if(musicFileModel.folder == "file://" + rootMusic) {
                        musicFileModel.folder = "";
                    }
                    musicFileModel.folder = rootMusic
                }
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
            name: searchField.text.length > 0 ? "edit-clear" : "find"
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if(searchField.text.length > 0) {
                        searchField.text = ""
                        searchField.focus = false
                    } else if(musicFileModel.folder == "file://" + rootMusic) {
                        musicFileModel.folder = "";
                    }
                    musicFileModel.folder = rootMusic
                }
            }
        }
    }

    // Selection action bar
    Rectangle {
        id: selectionBar
        visible: selectionMode
        height: visible ? units.gu(5) : 0
        anchors.top: searchBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        color: "#E95420"

        RowLayout {
            anchors.fill: parent
            anchors.margins: units.gu(1)
            spacing: units.gu(1)

            Button {
                text: i18n.tr("Play (%1)").arg(selectedSongs.length)
                Layout.fillWidth: true
                onClicked: playSelected()
            }
            Button {
                text: i18n.tr("Save")
                Layout.fillWidth: true
                onClicked: saveSelectedAsPlaylist()
            }
            Button {
                text: i18n.tr("All")
                Layout.fillWidth: true
                onClicked: selectAll()
            }
            Button {
                text: i18n.tr("None")
                Layout.fillWidth: true
                onClicked: deselectAll()
            }
        }
    }

    // Song list
    ListView {
        id: searchMusicView
        model: searchResults
        width: parent.width
        anchors {
            fill: parent
            rightMargin: units.gu(2)
            leftMargin: units.gu(2)
            topMargin: selectionMode ? units.gu(11) : units.gu(6)
            bottomMargin: musicPlayer.visible ? musicPlayer.height : 0
        }
        clip: true
        focus: true
        cacheBuffer: height

        delegate: Item {
            width: searchMusicView.width
            height: searchMusicViewName.implicitHeight + units.gu(2)

            Rectangle {
                id: searchMusicRectangle
                opacity: 0.9
                color: isSelected(filePath) ? "#333333" : "#111111"
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
                        color: isSelected(filePath) ? "#E95420" : "transparent"
                        border.color: "#FFFFFF"
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !fileIsDir

                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            color: "#FFFFFF"
                            visible: isSelected(filePath)
                            font.pixelSize: units.gu(1.5)
                        }
                    }

                    Icon {
                        id: searchMusicViewItem
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
            }
        }
    }
}
