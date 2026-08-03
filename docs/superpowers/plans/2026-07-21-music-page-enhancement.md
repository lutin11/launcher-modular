# Music Page Enhancement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add multi-selection, playlist save/load, and a built-in music player to the Music page.

**Architecture:** Three QML components — refactored Music.qml (selection + list), new MusicPlayer.qml (bottom playback bar), new Playlists.qml (JSON save/load). Qt Multimedia MediaPlayer for playback. No C++ changes.

**Tech Stack:** Qt5 QML, Qt Multimedia (MediaPlayer, AudioOutput), Qt.labs.settings, FolderListModel

## Global Constraints

- Branch: `feature/music-page-enhancement`
- Framework: Ubuntu Touch 24.04 (Lomiri)
- Qt version: 5.12+
- Build: `clickable build --arch arm64` or `clickable desktop`
- No new C++ code — QML only
- Volume controlled via system settings (no in-app volume control)
- Playlists stored as JSON in `~/.launchermodular/playlists/`

---

### Task 1: Add Qt Multimedia dependency

**Files:**
- Modify: `clickable.yaml`

**Interfaces:**
- Consumes: None (first task)
- Produces: `qml-module-qtmultimedia` available at build time

- [ ] **Step 1: Add multimedia dependency**

In `clickable.yaml`, add `qml-module-qtmultimedia` to `dependencies_target`:

```yaml
clickable_minimum_required:
    "8.4.0"
skip_review: true  
builder:
    "cmake"
kill:
    "launchermodular.lut11"
dependencies_target: [
    "libpam0g-dev",
    "libgsettings-qt-dev",
    "qml-module-qtmultimedia"
    ]
```

- [ ] **Step 2: Verify build**

```bash
clickable build --arch amd64
```

Expected: Build succeeds, no missing module errors.

- [ ] **Step 3: Commit**

```bash
git add clickable.yaml
git commit -m "feat: add qml-module-qtmultimedia dependency"
```

---

### Task 2: Add playlist settings to Main.qml

**Files:**
- Modify: `qml/Main.qml`

**Interfaces:**
- Consumes: None
- Produces: `launchermodular.settings.currentPlaylistName`, `currentPlaylistSongs`, `currentSongIndex`

- [ ] **Step 1: Add settings properties**

In `qml/Main.qml`, inside the `Settings` block (after `property bool fullScreen: false` around line 153), add:

```qml
property string currentPlaylistName: ""
property var currentPlaylistSongs: []
property int currentSongIndex: -1
```

- [ ] **Step 2: Verify build**

```bash
clickable build --arch amd64
```

Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add qml/Main.qml
git commit -m "feat: add playlist settings properties"
```

---

### Task 3: Create Playlists.qml — playlist save/load/delete

**Files:**
- Create: `qml/pages/Playlists.qml`

**Interfaces:**
- Consumes: None (standalone utility)
- Produces: `Playlists.savePlaylist(name, songs)`, `Playlists.loadPlaylist(name)`, `Playlists.listPlaylists()`, `Playlists.deletePlaylist(name)`

- [ ] **Step 1: Create Playlists.qml**

Create `qml/pages/Playlists.qml`:

```qml
import QtQuick 2.12
import Qt.labs.settings 1.0
import MySettings 1.0

QtObject {
    id: playlists

    property string playlistsDir: MySettings.getHomeLocation() + "/.launchermodular/playlists"

    function ensureDir() {
        // Directory is created on first save via FolderListModel
    }

    function savePlaylist(name, songs) {
        var content = JSON.stringify({
            "name": name,
            "created": new Date().toISOString(),
            "songs": songs
        }, null, 2)
        var xhr = new XMLHttpRequest()
        xhr.open("PUT", "file://" + playlistsDir + "/" + name + ".json", false)
        xhr.send(content)
        return xhr.status === 0 || xhr.status === 200
    }

    function loadPlaylist(name) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "file://" + playlistsDir + "/" + name + ".json", false)
        xhr.send()
        if (xhr.status === 200 || xhr.status === 0) {
            try {
                return JSON.parse(xhr.responseText)
            } catch(e) {
                return null
            }
        }
        return null
    }

    function listPlaylists() {
        var result = []
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "file://" + playlistsDir + "/", false)
        xhr.send()
        // FolderListModel approach — fallback to settings
        var stored = launchermodular.settings.playlistNames
        if (typeof stored !== 'undefined' && stored !== null) {
            result = stored
        }
        return result
    }

    function deletePlaylist(name) {
        var xhr = new XMLHttpRequest()
        xhr.open("DELETE", "file://" + playlistsDir + "/" + name + ".json", false)
        xhr.send()
        // Remove from stored names
        var names = launchermodular.settings.playlistNames || []
        var idx = names.indexOf(name)
        if (idx !== -1) {
            names.splice(idx, 1)
            launchermodular.settings.playlistNames = names
        }
    }
}
```

- [ ] **Step 2: Add playlistNames to settings**

In `qml/Main.qml`, inside the `Settings` block, add:

```qml
property var playlistNames: []
```

- [ ] **Step 3: Verify build**

```bash
clickable build --arch amd64
```

Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add qml/pages/Playlists.qml qml/Main.qml
git commit -m "feat: add Playlists.qml for save/load/delete"
```

---

### Task 4: Create MusicPlayer.qml — bottom playback bar

**Files:**
- Create: `qml/pages/MusicPlayer.qml`

**Interfaces:**
- Consumes: `launchermodular.settings.currentSongIndex`, `currentPlaylistSongs`
- Produces: `MusicPlayer.play(songPath)`, `MusicPlayer.playList(songs)`, `MusicPlayer.pause()`, `MusicPlayer.stop()`, `MusicPlayer.next()`, `MusicPlayer.previous()`, signals: `playingChanged`, `songChanged`

- [ ] **Step 1: Create MusicPlayer.qml**

Create `qml/pages/MusicPlayer.qml`:

```qml
import QtQuick 2.12
import QtQuick.Layouts 1.12
import Lomiri.Components 1.3
import QtMultimedia 5.12

Rectangle {
    id: musicPlayer
    visible: false
    height: visible ? units.gu(10) : 0
    color: "#111111"
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom

    property var playlist: []
    property int currentIndex: -1
    property bool isPlaying: false
    property string currentSongName: ""

    signal songChanged(string name, int index)
    signal playingChanged(bool playing)

    function play(songPath) {
        mediaPlayer.source = songPath
        mediaPlayer.play()
        isPlaying = true
        visible = true
        playingChanged(true)
    }

    function playList(songs) {
        playlist = songs
        currentIndex = 0
        if (songs.length > 0) {
            play(songs[0].path)
            currentSongName = songs[0].name
            songChanged(currentSongName, currentIndex)
        }
    }

    function pause() {
        mediaPlayer.pause()
        isPlaying = false
        playingChanged(false)
    }

    function resume() {
        mediaPlayer.play()
        isPlaying = true
        playingChanged(true)
    }

    function stop() {
        mediaPlayer.stop()
        isPlaying = false
        visible = false
        currentIndex = -1
        currentSongName = ""
        playingChanged(false)
    }

    function next() {
        if (playlist.length === 0) return
        currentIndex = (currentIndex + 1) % playlist.length
        play(playlist[currentIndex].path)
        currentSongName = playlist[currentIndex].name
        songChanged(currentSongName, currentIndex)
    }

    function previous() {
        if (playlist.length === 0) return
        currentIndex = (currentIndex - 1 + playlist.length) % playlist.length
        play(playlist[currentIndex].path)
        currentSongName = playlist[currentIndex].name
        songChanged(currentSongName, currentIndex)
    }

    MediaPlayer {
        id: mediaPlayer
        onPositionChanged: {
            if (duration > 0) {
                progressSlider.value = position / duration
            }
        }
        onStatusChanged: {
            if (status === MediaPlayer.EndOfMedia) {
                musicPlayer.next()
            }
        }
    }

    AudioOutput {
        id: audioOutput
    }

    // Connect player to audio output
    Component.onCompleted: {
        mediaPlayer.audioOutput = audioOutput
    }

    Column {
        anchors.fill: parent
        anchors.margins: units.gu(1)

        // Progress bar
        Slider {
            id: progressSlider
            width: parent.width
            minimumValue: 0
            maximumValue: 1
            live: false
            onValueChanged: {
                if (mediaPlayer.duration > 0 && !pressed) {
                    // Seek handled by pressed check
                }
            }
            onPressedChanged: {
                if (!pressed && mediaPlayer.duration > 0) {
                    mediaPlayer.seek(progressSlider.value * mediaPlayer.duration)
                }
            }
        }

        RowLayout {
            width: parent.width
            spacing: units.gu(2)

            // Previous
            Button {
                Layout.fillWidth: false
                width: units.gu(5)
                height: units.gu(4)
                text: "◄◄"
                onClicked: musicPlayer.previous()
            }

            // Play/Pause
            Button {
                Layout.fillWidth: false
                width: units.gu(6)
                height: units.gu(4)
                text: musicPlayer.isPlaying ? "❚❚" : "▶"
                onClicked: {
                    if (musicPlayer.isPlaying) {
                        musicPlayer.pause()
                    } else {
                        musicPlayer.resume()
                    }
                }
            }

            // Next
            Button {
                Layout.fillWidth: false
                width: units.gu(5)
                height: units.gu(4)
                text: "►►"
                onClicked: musicPlayer.next()
            }

            // Song name
            Label {
                Layout.fillWidth: true
                text: musicPlayer.currentSongName
                color: "#FFFFFF"
                elide: Text.ElideRight
                fontSize: "small"
            }

            // Close
            Button {
                Layout.fillWidth: false
                width: units.gu(4)
                height: units.gu(4)
                text: "✕"
                onClicked: musicPlayer.stop()
            }
        }
    }
}
```

- [ ] **Step 2: Verify build**

```bash
clickable build --arch amd64
```

Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add qml/pages/MusicPlayer.qml
git commit -m "feat: add MusicPlayer.qml bottom playback bar"
```

---

### Task 5: Refactor Music.qml — add multi-selection + action bar

**Files:**
- Modify: `qml/pages/Music.qml`

**Interfaces:**
- Consumes: `MusicPlayer.playList()`, `Playlists.savePlaylist()`, `Playlists.loadPlaylist()`
- Produces: Selection state, action bar UI

- [ ] **Step 1: Add selection model and action bar to Music.qml**

Replace the entire `qml/pages/Music.qml` with the following:

```qml
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
```

- [ ] **Step 4: Verify build**

```bash
clickable build --arch amd64
```

Expected: Build succeeds.

- [ ] **Step 5: Commit**

```bash
git add qml/pages/Music.qml
git commit -m "feat: refactor Music.qml with multi-selection and action bar"
```

---

### Task 6: Wire MusicPlayer into Home.qml

**Files:**
- Modify: `qml/pages/Home.qml`

**Interfaces:**
- Consumes: `MusicPlayer` component
- Produces: Music player accessible from home page

- [ ] **Step 1: Add MusicPlayer import and instance**

In `qml/pages/Home.qml`, after the `import` statements (around line 14), no import changes needed since MusicPlayer is in the same directory.

Add a `MusicPlayer` instance inside the `Item { id: home }` block, after the `property bool reloading: false` line (around line 80):

```qml
MusicPlayer { id: homeMusicPlayer }
```

- [ ] **Step 2: Verify build**

```bash
clickable build --arch amd64
```

Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add qml/pages/Home.qml
git commit -m "feat: add MusicPlayer instance to Home page"
```

---

### Task 7: Final build verification and cleanup

**Files:**
- Verify all modified files

**Interfaces:**
- Consumes: All previous tasks
- Produces: Working build, no warnings

- [ ] **Step 1: Full clean build**

```bash
clickable build --arch amd64
```

Expected: Build succeeds with no errors.

- [ ] **Step 2: Verify all files are committed**

```bash
git status
```

Expected: Clean working tree (or only unrelated changes).

- [ ] **Step 3: Final commit if needed**

```bash
git add -A && git commit -m "chore: final cleanup for music page enhancement"
```

Only if there are uncommitted changes.
