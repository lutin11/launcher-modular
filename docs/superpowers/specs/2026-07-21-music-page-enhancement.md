# Music Page Enhancement — Design Spec

## Overview

Add multi-selection, playlist management, and a built-in music player to the Music page. Currently, tapping a song opens an external player. This enhancement keeps users inside the launcher with selection, playlist save/load, and inline playback controls.

## Components

### 1. Music.qml (refactored)

The existing Music page gets multi-selection support:

- **Tap a song** → toggles selection (checkbox appears, row highlighted)
- **Tap a folder** → navigates into folder (unchanged behavior)
- **Selection count** displayed in header when > 0
- **Action bar** appears at bottom when selection > 0 with:
  - "Play Selected (N)" button — starts playback of selected songs
  - "Save Playlist" button — saves selection to JSON
  - "Select All / Deselect All" toggle

The existing search, folder navigation, and debounce logic remain unchanged.

### 2. MusicPlayer.qml (new component)

A bottom bar that appears when music is playing:

```
┌──────────────────────────────────┐
│  ◄◄   ▶/❚❚   ►►   ━━━●━━━━    │
│  Now: Song Name.mp3    1:23/3:45│
└──────────────────────────────────┘
```

**Controls:**
- Previous / Play-Pause / Next buttons
- Progress slider (seekable)
- Current song name + elapsed/total time
- Swipe down or tap close to dismiss (stops playback)

**Qt Multimedia usage:**
```qml
MediaPlayer {
    id: mediaPlayer
    source: currentSongPath
    onPlaybackStateChanged: { /* update UI */ }
    onPositionChanged: { /* update slider */ }
}
AudioOutput {
    id: audioOutput
    volume: volumeSlider.value
}
```

### 3. Playlists.qml (new component)

Manages saved playlists as JSON files.

**Storage location:** `~/.launchermodular/playlists/`

**JSON format:**
```json
{
    "name": "My Playlist",
    "created": "2026-07-21T10:30:00",
    "songs": [
        {"path": "file:///path/to/song1.mp3", "name": "Song 1"},
        {"path": "file:///path/to/song2.mp3", "name": "Song 2"}
    ]
}
```

**Operations:**
- `savePlaylist(name, songs)` — writes JSON file
- `loadPlaylist(name)` — reads JSON, returns song list
- `listPlaylists()` — returns all saved playlist names
- `deletePlaylist(name)` — removes JSON file

**UI access:**
- "Load Playlist" button in the Music page header (when no selection)
- Shows a list of saved playlists; tapping one loads it into selection
- Long-press on a playlist name to delete

### 4. Settings additions

New properties in `Main.qml` settings:
```qml
property string currentPlaylistName: ""
property var currentPlaylistSongs: []
property int currentSongIndex: -1
property real musicVolume: 0.8
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `qml/pages/Music.qml` | Modify | Add multi-select, action bar, integrate player |
| `qml/pages/MusicPlayer.qml` | Create | Bottom player bar component |
| `qml/pages/Playlists.qml` | Create | Playlist save/load/delete logic |
| `qml/Main.qml` | Modify | Add playlist settings properties |
| `clickable.yaml` | Modify | Add `qml-module-qtmultimedia` dependency |
| `po/*.pot` + `po/*.po` | Update | New translatable strings |

## Dependencies

- `qml-module-qtmultimedia` — for `MediaPlayer` and `AudioOutput`
- No new C++ code needed

## Out of Scope

- Shuffle/repeat modes (can be added later)
- Queue management (start with linear playlist playback)
- Album art display in player bar
- Sleep timer
