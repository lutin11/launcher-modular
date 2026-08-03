# Playlist Save & Toggle Design

## Overview

Fix the broken save dialog and add a playlist toggle to MusicPlayer that switches between song list and playlist list views.

## Problems

1. `PopupUtils.open(savePlaylistDialog)` fails silently — dialog never displays
2. `PlaylistsView.qml` exists but is never loaded from any page (dead code)
3. No way to access saved playlists from the Music page

## Solution

### 1. Save Fix — Inline Overlay

Replace `PopupUtils.open()` with an inline overlay Rectangle in Music.qml:
- Appears when user taps Save (floppy disk icon)
- Contains a TextField for playlist name + Save/Cancel buttons
- Calls `playlistManager.savePlaylist(name, selectedSongs)`
- Hides after save or cancel

### 2. Dynamic Toolbar Icon

MusicPlayer toolbar adapts based on selection state:

**No selection:**
```
[Shuffle] [Prev] [Play/Pause] [Next] [Repeat] [Playlists]
```

**Songs selected:**
```
[Shuffle] [Prev] [Play/Pause] [Next] [Repeat] [Save 💾]
```

- Playlists icon (`media-playlist`) → Save icon (`media-floppy`) when `selectedSongs.length > 0`
- Tap Save → opens inline save overlay
- Tap Playlists → toggles playlist list view

### 3. Playlist List View

When Playlists button tapped (no selection):
- MusicPlayer height expands from `units.gu(10)` to `units.gu(25)`
- Below player controls, show ListView of saved playlists
- Each row: playlist name + track count + play icon
- Tap playlist → loads into MusicPlayer → collapses list
- Tap Playlists icon again → collapses list

### 4. Loading Playlists

When playlist selected from list:
1. `playlistManager.loadPlaylist(name)` returns `[{path, name}]`
2. Call `musicPlayer.playList(tracks)` to start playing
3. Collapse playlist view (`showPlaylists = false`)

## Files Modified

| File | Changes |
|------|---------|
| `qml/pages/MusicPlayer.qml` | Add playlistManager/selectedSongs/selectionMode properties, dynamic toolbar icon, playlist list view, save/load functions |
| `qml/pages/Music.qml` | Add inline save overlay, pass properties to MusicPlayer, remove old save dialog |

## Files Unchanged

| File | Reason |
|------|--------|
| `PlaylistManager.qml` | Already works correctly |
| `PlaylistsView.qml` | Dead code, not needed for this design |

## Data Flow

```
Music.qml
  ├── selectedSongs[] ──────→ MusicPlayer.selectedSongs
  ├── selectionMode ────────→ MusicPlayer.selectionMode
  ├── playlistManager ──────→ MusicPlayer.playlistManager
  └── saveOverlay visible ←── MusicPlayer.saveRequested signal

MusicPlayer.qml
  ├── showPlaylists → toggles playlist list height
  ├── saveRequested → Music.qml shows save overlay
  ├── loadPlaylist(name) → playlistManager.loadPlaylist() → playList()
  └── savePlaylist(name) → playlistManager.savePlaylist(name, selectedSongs)
```

## UI States

### State 1: Default (no selection, playlists hidden)
```
┌─────────────────────────────────┐
│ [⏮] [⏯] [⏭]  🔀  🔁  📋      │ ← MusicPlayer controls
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │ ← progress bar
│ Song: Christine.mp3      [✕]   │
│ ▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░ │ ← bottom progress
└─────────────────────────────────┘
[Song list below...]
```

### State 2: Songs selected (selection mode)
```
┌─────────────────────────────────┐
│ [⏮] [⏯] [⏭]  🔀  🔁  💾      │ ← Save icon
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│ 2 songs selected        [Clear]│
│ ▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░ │
└─────────────────────────────────┘
[Song list with checkboxes...]
```

### State 3: Save overlay
```
┌─────────────────────────────────┐
│ [⏮] [⏯] [⏭]  🔀  🔁  💾      │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│ Playlist name: [____________]   │
│ [Save]              [Cancel]    │
│ ▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░ │
└─────────────────────────────────┘
```

### State 4: Playlists view (toggled)
```
┌─────────────────────────────────┐
│ [⏮] [⏯] [⏭]  🔀  🔁  📋      │ ← Playlists icon
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│ Song: Christine.mp3      [✕]   │
│ ▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░ │
├─────────────────────────────────┤
│ 🎵 My Favorites      12 tracks ▶│ ← playlist list
│ 🎵 Road Trip          8 tracks ▶│
│ 🎵 Workout            5 tracks ▶│
│                               │
│ No playlists yet...           │
└─────────────────────────────────┘
```
