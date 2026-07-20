# Critical Bug Fixes for launcher-modular

## Overview

Fix critical bugs in the launcher-modular codebase: memory leaks, dead QML handlers, UI thread blocking, and crash bugs. Organized into 4 category-based commits on a new branch from `develop`.

## Branch

`fix/critical-bugs` branched from `develop`

---

## Commit 1: Fix memory leaks in AppHandler plugin

**File:** `plugins/AppHandler/apphandler.cpp`

### Bug: `_appinfos.clear()` leaks all `AppInfo*` objects

`reload()` (line 201-202) calls `_appinfos.clear()` and `_fav_appinfos.clear()` without freeing the heap-allocated `AppInfo*` objects. The `clear_appinfo` callback (line 196-198) has the same issue.

**Fix:** Add `qDeleteAll(_appinfos)` before `clear()` in both `reload()` and `clear_appinfo`. Same for `_fav_appinfos` in `reload()`.

### Bug: `loadLibertineAppsFromDir` references wrong `AppInfo`

Line 64: `AppInfo* app = _appinfos.last()` gets the **last** element from a prior iteration, not the newly created object on line 67. Icon resolution on lines 69-80 modifies the wrong object.

**Fix:** Capture the return value of the `new AppInfo(...)` append. Refactor to:
```cpp
AppInfo* newApp = new AppInfo(...);
_appinfos.append(newApp);
// Then resolve icon on newApp
```

### Bug: `reloadFav()` mutates `_appinfos` while iterating

Lines 207-222: `takeFirst()` and `takeAt()` modify the list during iteration, causing skipped or duplicate elements.

**Fix:** Build a separate list of favorites first, then reassign `_fav_appinfos` and `_appinfos` in one pass.

---

## Commit 2: Fix memory leak in LibertineLauncher plugin

**File:** `plugins/LibertineLauncher/libertinelauncher.cpp`

### Bug: `LibertineWorker` heap-allocated without cleanup

Line 13: `new LibertineWorker(containerName, appName)` creates a worker without a parent. `run()` blocks until the process finishes, then the object is never deleted.

**Fix:** Set the launcher as parent: `new LibertineWorker(containerName, appName, this)`. The worker will be auto-deleted when the launcher is destroyed. Since `run()` blocks, this is acceptable.

**File:** `plugins/LibertineLauncher/libertineworker.cpp`

### Bug: `waitForFinished(-1)` blocks indefinitely

Line 29: No timeout on process wait.

**Fix:** Change to `waitForFinished(30000)` (30 seconds) with a fallback.

---

## Commit 3: Fix nested onClicked bugs in QML pages

The pattern `onClicked: { onClicked: ... }` is a QML bug. The inner `onClicked:` creates a new property assignment on the handler scope instead of calling the code. The handler never fires.

### Home.qml

- **Line 57-59** (Cancel button in auth dialog): `onClicked: { onClicked: PopupUtils.close(authentDialogue); }` — fix to `onClicked: PopupUtils.close(authentDialogue)`
- **Line 483-485** (Cancel button in apps dialog): Same pattern — fix to `onClicked: PopupUtils.close(appsDialogue)`

### Music.qml

- **Line 254-256** (Music file click): `onClicked: { if (!fileIsDir) { onClicked:Qt.openUrlExternally(...) } }` — fix to `onClicked: { if (!fileIsDir) { Qt.openUrlExternally("music://" + model.filePath) } else { ... } }`

### Picture.qml

- **Line 74-76** (Photo click): `onClicked: { onClicked:Qt.openUrlExternally(...) }` — fix to `onClicked: Qt.openUrlExternally("photo://" + filePath)`

### Videos.qml

- **Line 252-254** (Video file click): Same pattern as Music.qml — fix to `onClicked: { if (!fileIsDir) { Qt.openUrlExternally("video://" + model.filePath) } else { ... } }`

---

## Commit 4: Fix crashes and UI blocking

### Crash: ChangeLogs.qml line 240

`changeLogModel.get(index+1).version.length` — when `index` is the last item, `get(index+1)` returns `undefined`, and `.version.length` crashes.

**Fix:** Add bounds check: `if (index < changeLogModel.count - 1 && changeLogModel.get(index+1).version.length > 0)`

### Crash: Pagemanagement.qml line 143

`visible: if(fileName && fileName.split(".")[0] == "Home"){false; height = 0} else {true}` — semicolons inside binding expression are incorrect QML. `height = 0` inside a `visible` binding does nothing.

**Fix:** Simplify to `visible: !(fileName && fileName.split(".")[0] === "Home")` and move height control outside.

### UI Blocking: terminalaccess.cpp lines 19-20, 27

`_proc.waitForFinished()` and `_proc.waitForStarted()` block the UI thread.

**Fix:** Add timeouts: `_proc.waitForFinished(5000)` and `_proc.waitForStarted(5000)`.

### Bug: terminalaccess.cpp line 62

`emit(needSudoPassword()); needSudoPassword();` — signal emitted AND function called directly, causing double invocation.

**Fix:** Remove the direct call, keep only `emit needSudoPassword();`.

### Bug: terminalaccess.cpp line 69

`newErrorAvailable()` called without `emit` keyword.

**Fix:** Add `emit`: `emit newErrorAvailable();`

### Bug: terminalaccess.cpp lines 21-23 indentation

The `qDebug` on line 22 is indented inside the `if(reset_err)` block, but `_err.clear()` on line 23 is outside. This means `_err.clear()` always runs regardless of `reset_err`.

**Fix:** Properly indent both lines inside the `if(reset_err)` block.

---

## Files Modified (10 total)

| File | Commit |
|------|--------|
| `plugins/AppHandler/apphandler.cpp` | 1 |
| `plugins/LibertineLauncher/libertinelauncher.cpp` | 2 |
| `plugins/LibertineLauncher/libertineworker.cpp` | 2 |
| `qml/pages/Home.qml` | 3 |
| `qml/pages/Music.qml` | 3 |
| `qml/pages/Picture.qml` | 3 |
| `qml/pages/Videos.qml` | 3 |
| `qml/ChangeLogs.qml` | 4 |
| `qml/Pagemanagement.qml` | 4 |
| `plugins/Terminalaccess/terminalaccess.cpp` | 4 |

## Testing

Build with `clickable build --arch arm64` or `clickable desktop`. Manual verification:
- Open launcher, pull to refresh (triggers `reload()` — verify no crash)
- Open app context menu → Cancel (verifies nested onClicked fix)
- Open Music/Videos/Picture pages and tap files (verifies onClicked fix)
- Run a terminal command (verifies no UI freeze)
- View Change Logs page (verifies no crash on last item)
