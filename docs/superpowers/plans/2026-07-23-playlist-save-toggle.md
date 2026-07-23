# Playlist Save & Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the broken save dialog and add a playlist toggle to MusicPlayer that switches between song list and playlist list views.

**Architecture:** Modify MusicPlayer.qml to accept playlist-related properties from Music.qml, add dynamic toolbar icon (Playlists ↔ Save), inline save overlay, and expandable playlist list view. Modify Music.qml to remove old save dialog, add inline save overlay, and pass properties to MusicPlayer.

**Tech Stack:** Qt5/QML, QtQuick.Controls 2.2, Lomiri.Components 1.3, QtQuick.LocalStorage 2.0 (via existing PlaylistManager)

## Global Constraints

- Qt5/QML with C++11
- QtQuick 2.12, QtQuick.Layouts 1.12, QtQuick.Controls 2.2
- Lomiri.Components 1.3, Lomiri.Components.Popups 1.3
- MySettings 1.0 for paths
- PlaylistManager uses LocalStorage (SQLite)
- No new plugins or C++ changes required

---

### Task 1: Add Properties to MusicPlayer.qml

**Files:**
- Modify: `qml/pages/MusicPlayer.qml`

**Interfaces:**
- Consumes: `playlistManager` (object), `selectedSongs` (array), `selectionMode` (bool) from Music.qml
- Produces: `showPlaylists` (bool), `saveRequested` (signal)

- [ ] **Step 1: Add new properties and signal to MusicPlayer.qml**

Add after line 28 (`property int copyIndex: 0`):

```qml
    property var playlistManager: null
    property var selectedSongs: []
    property bool selectionMode: false
    property bool showPlaylists: false

    signal saveRequested()
```

- [ ] **Step 2: Commit**

```bash
git add qml/pages/MusicPlayer.qml
git commit -m "feat: add playlist properties and signal to MusicPlayer"
```

---

### Task 2: Dynamic Toolbar Icon in MusicPlayer.qml

**Files:**
- Modify: `qml/pages/MusicPlayer.qml`

**Interfaces:**
- Consumes: `selectionMode` (bool) from Task 1
- Produces: Updated Playlists/Save icon in toolbar

- [ ] **Step 1: Replace the Repeat button's sibling Playlists/Save button**

Find the Repeat button MouseArea (around line 420-435) and add a new button after it. Replace the existing code block for the repeat button section with:

```qml
            // Repeat button
            MouseArea {
                Layout.fillWidth: false
                Layout.preferredWidth: units.gu(4)
                height: units.gu(4)
                onClicked: toggleRepeat()

                Icon {
                    anchors.centerIn: parent
                    height: units.gu(2)
                    width: units.gu(2)
                    name: repeatMode === "single" ? "media-playlist-repeat-one" : "media-playlist-repeat"
                    color: repeatMode !== "none" ? "#E95420" : "#FFFFFF"
                    opacity: repeatMode !== "none" ? 1 : 0.4
                }
            }

            // Playlists / Save button (context-dependent)
            MouseArea {
                Layout.fillWidth: false
                Layout.preferredWidth: units.gu(4)
                height: units.gu(4)
                onClicked: {
                    if (musicPlayer.selectionMode) {
                        musicPlayer.saveRequested()
                    } else {
                        musicPlayer.showPlaylists = !musicPlayer.showPlaylists
                    }
                }

                Icon {
                    anchors.centerIn: parent
                    height: units.gu(2)
                    width: units.gu(2)
                    name: musicPlayer.selectionMode ? "media-floppy" : "media-playlist"
                    color: musicPlayer.selectionMode ? "#FFFFFF" : (musicPlayer.showPlaylists ? "#E95420" : "#FFFFFF")
                    opacity: musicPlayer.showPlaylists || musicPlayer.selectionMode ? 1 : 0.4
                }
            }
```

- [ ] **Step 2: Update MusicPlayer height to support playlist view**

Change the height property (line 11) from:

```qml
    height: visible ? units.gu(10) : 0
```

to:

```qml
    height: visible ? (showPlaylists ? units.gu(25) : units.gu(10)) : 0
```

- [ ] **Step 3: Commit**

```bash
git add qml/pages/MusicPlayer.qml
git commit -m "feat: add dynamic toolbar icon and expandable height to MusicPlayer"
```

---

### Task 3: Playlist List View in MusicPlayer.qml

**Files:**
- Modify: `qml/pages/MusicPlayer.qml`

**Interfaces:**
- Consumes: `playlistManager` (object), `showPlaylists` (bool) from Task 1
- Produces: Playlist list UI, `loadPlaylist(name)` function

- [ ] **Step 1: Add playlist list model property**

Add after `property bool showPlaylists: false`:

```qml
    property var savedPlaylists: []
```

- [ ] **Step 2: Add loadPlaylist function**

Add after the `toggleRepeat()` function:

```qml
    function loadPlaylist(name) {
        if (!playlistManager) return
        var tracks = playlistManager.loadPlaylist(name)
        if (tracks.length === 0) return
        playList(tracks)
        showPlaylists = false
    }

    function refreshPlaylists() {
        if (!playlistManager) return
        savedPlaylists = playlistManager.loadPlaylists()
    }
```

- [ ] **Step 3: Add playlist list view below the progress bar**

Add after the bottom progress bar Rectangle (before the closing `}` of the main Rectangle):

```qml
    // Playlist list view (shown when showPlaylists is true)
    Rectangle {
        id: playlistPanel
        visible: musicPlayer.showPlaylists
        anchors.top: progressBar.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: "#111111"

        Component.onCompleted: refreshPlaylists()
        onVisibleChanged: if (visible) refreshPlaylists()

        ListView {
            id: playlistListView
            anchors.fill: parent
            anchors.margins: units.gu(0.5)
            clip: true
            model: musicPlayer.savedPlaylists

            delegate: Rectangle {
                width: playlistListView.width
                height: units.gu(5)
                color: "#222222"
                radius: units.gu(0.5)

                Row {
                    anchors.fill: parent
                    anchors.margins: units.gu(0.5)
                    spacing: units.gu(1)

                    Icon {
                        height: units.gu(3)
                        width: units.gu(3)
                        anchors.verticalCenter: parent.verticalCenter
                        name: "media-playlist"
                        color: "#E95420"
                    }

                    Column {
                        width: parent.width - units.gu(8)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: modelData
                            color: "#FFFFFF"
                            font.pixelSize: units.gu(1.5)
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Text {
                            text: playlistManager ? playlistManager.getPlaylistCount(modelData) + " tracks" : ""
                            color: "#aaaaaa"
                            font.pixelSize: units.gu(1)
                        }
                    }

                    Icon {
                        height: units.gu(2.5)
                        width: units.gu(2.5)
                        anchors.verticalCenter: parent.verticalCenter
                        name: "media-playback-start"
                        color: "#0E8420"

                        MouseArea {
                            anchors.fill: parent
                            onClicked: musicPlayer.loadPlaylist(modelData)
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: musicPlayer.loadPlaylist(modelData)
                    propagateComposedEvents: true
                }
            }

            // Empty state
            Text {
                anchors.centerIn: parent
                text: "No playlists yet.\nSelect songs and tap Save to create one."
                color: "#aaaaaa"
                font.pixelSize: units.gu(1.2)
                horizontalAlignment: Text.AlignHCenter
                visible: playlistListView.count === 0
            }
        }
    }
```

- [ ] **Step 4: Commit**

```bash
git add qml/pages/MusicPlayer.qml
git commit -m "feat: add playlist list view to MusicPlayer"
```

---

### Task 4: Inline Save Overlay in Music.qml

**Files:**
- Modify: `qml/pages/Music.qml`

**Interfaces:**
- Consumes: `saveRequested` signal from MusicPlayer (Task 1)
- Produces: `showSaveOverlay` (bool), inline save UI

- [ ] **Step 1: Add save overlay state property**

Add after `property bool selectionMode: false` (line 23):

```qml
    property bool showSaveOverlay: false
```

- [ ] **Step 2: Connect to MusicPlayer saveRequested signal**

In the `Component.onCompleted` block (around line 29-31), add:

```qml
    Component.onCompleted: {
        musicPlayer.cleanupCache()
        musicPlayer.saveRequested.connect(function() {
            showSaveOverlay = true
        })
    }
```

- [ ] **Step 3: Remove old savePlaylistDialog Component**

Delete the entire `Component { id: savePlaylistDialog ... }` block (lines 200-233).

- [ ] **Step 4: Update saveSelectedAsPlaylist function**

Replace the `saveSelectedAsPlaylist` function (line 46-48) with:

```qml
    function saveSelectedAsPlaylist() {
        if (selectedSongs.length === 0) return
        showSaveOverlay = true
    }
```

- [ ] **Step 5: Add inline save overlay Rectangle**

Add before the closing `}` of the main Item (before line 467):

```qml
    // Inline save overlay
    Rectangle {
        id: saveOverlay
        visible: musics.showSaveOverlay
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: units.gu(6)
        color: "#1a1a1a"
        z: 100

        Column {
            anchors.fill: parent
            anchors.margins: units.gu(1)
            spacing: units.gu(0.5)

            TextField {
                id: playlistNameField
                placeholderText: i18n.tr("Playlist name")
                width: parent.width
                height: units.gu(3.5)
                color: "#FFFFFF"
                onAccepted: savePlaylistAction()
            }

            Row {
                width: parent.width
                spacing: units.gu(1)

                Button {
                    text: i18n.tr("Save")
                    width: parent.width / 2
                    height: units.gu(3)
                    color: "#0E8420"
                    onClicked: savePlaylistAction()
                }

                Button {
                    text: i18n.tr("Cancel")
                    width: parent.width / 2
                    height: units.gu(3)
                    onClicked: {
                        showSaveOverlay = false
                        playlistNameField.text = ""
                    }
                }
            }
        }

        function savePlaylistAction() {
            if (playlistNameField.text.length > 0 && playlistManager) {
                playlistManager.savePlaylist(playlistNameField.text, selectedSongs)
                showSaveOverlay = false
                playlistNameField.text = ""
                deselectAll()
            }
        }
    }

    // Pass properties to MusicPlayer
    Component.onCompleted: {
        musicPlayer.playlistManager = playlistManager
    }
```

- [ ] **Step 6: Wire up selectedSongs and selectionMode to MusicPlayer**

Add bindings to MusicPlayer in the component instantiation area. The MusicPlayer is on line 27. Change:

```qml
    MusicPlayer { id: musicPlayer }
```

to:

```qml
    MusicPlayer {
        id: musicPlayer
        playlistManager: musics.playlistManager
        selectedSongs: musics.selectedSongs
        selectionMode: musics.selectionMode
    }
```

- [ ] **Step 7: Commit**

```bash
git add qml/pages/Music.qml
git commit -m "feat: add inline save overlay and wire MusicPlayer properties"
```

---

### Task 5: Remove Old Selection Bar

**Files:**
- Modify: `qml/pages/Music.qml`

**Interfaces:**
- Consumes: Task 4 (save overlay replaces selection bar)
- Produces: Cleaner UI without redundant selection bar

- [ ] **Step 1: Find and remove the selection action bar**

Search for the selection bar Rectangle that contains Play/Save/All/None buttons. It should be a Rectangle with buttons for "Play", "Save", "All", "None". Remove the entire Rectangle block that contains these buttons, since the save functionality is now handled by the dynamic toolbar icon and inline overlay.

Look for a section like:

```qml
    // Selection bar
    Rectangle {
        ...
        Button { text: "Play" ... }
        Button { text: "Save" ... }
        Button { text: "All" ... }
        Button { text: "None" ... }
    }
```

Remove this entire block.

- [ ] **Step 2: Commit**

```bash
git add qml/pages/Music.qml
git commit -m "refactor: remove redundant selection action bar"
```

---

### Task 6: Test and Verify

**Files:**
- Test: Manual testing on device

**Interfaces:**
- Consumes: All previous tasks
- Produces: Verified working feature

- [ ] **Step 1: Build and deploy to device**

```bash
clickable build --arch arm64
clickable
```

- [ ] **Step 2: Test save functionality**

1. Open Music page
2. Select 2+ songs (tap to toggle checkboxes)
3. Verify toolbar shows floppy disk icon
4. Tap floppy disk → verify inline overlay appears
5. Type playlist name → tap Save
6. Verify overlay closes, selection clears, playlist saved

- [ ] **Step 3: Test playlist toggle**

1. With no songs selected, verify Playlists icon visible
2. Tap Playlists icon → verify playlist list expands below player
3. Verify saved playlists appear with track counts
4. Tap a playlist → verify it loads into MusicPlayer and list collapses
5. Tap Playlists icon again → verify list collapses

- [ ] **Step 4: Test edge cases**

1. Try saving with empty name → verify nothing happens
2. Try saving with duplicate name → verify it overwrites
3. Verify playlists persist after app restart
4. Verify delete works from playlist list (if implemented)

- [ ] **Step 5: Final commit if any fixes needed**

```bash
git add -A
git commit -m "fix: playlist save and toggle polish"
```
