# Critical Bug Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix critical bugs: memory leaks, dead QML handlers, UI thread blocking, and crash bugs across the launcher-modular codebase.

**Architecture:** Four category-based commits on branch `fix/critical-bugs`. Each commit targets a specific bug class: memory management, worker lifecycle, QML event handling, and crash/blocking fixes. No new files created — all changes are surgical fixes to existing code.

**Tech Stack:** Qt5/QML (Lomiri), C++11, CMake

## Global Constraints

- Branch from `develop`
- Qt5 Lomiri framework (Ubuntu Touch)
- No new dependencies
- No architectural changes — bug fixes only
- Build verified via `clickable build --arch arm64` or `clickable desktop`

---

### Task 1: Create branch and fix AppHandler memory leaks

**Files:**
- Modify: `plugins/AppHandler/apphandler.cpp`

**Interfaces:**
- Consumes: None (first task)
- Produces: Fixed memory management in AppHandler — `reload()`, `clear_appinfo()`, `loadLibertineAppsFromDir()` no longer leak

- [ ] **Step 1: Create branch**

```bash
git checkout develop
git pull
git checkout -b fix/critical-bugs
```

- [ ] **Step 2: Fix `clear_appinfo` to free memory**

In `plugins/AppHandler/apphandler.cpp`, line 196-199, change:

```cpp
void AppHandler::clear_appinfo(QQmlListProperty<AppInfo> *list) {
    AppHandler *apphandler = qobject_cast<AppHandler*>(list->object);
    apphandler->_appinfos.clear();
    emit apphandler->appinfoChanged();
}
```

to:

```cpp
void AppHandler::clear_appinfo(QQmlListProperty<AppInfo> *list) {
    AppHandler *apphandler = qobject_cast<AppHandler*>(list->object);
    qDeleteAll(apphandler->_appinfos);
    apphandler->_appinfos.clear();
    emit apphandler->appinfoChanged();
}
```

- [ ] **Step 3: Fix `reload` to free memory**

In `plugins/AppHandler/apphandler.cpp`, lines 201-204, change:

```cpp
void AppHandler::reload() {
    _appinfos.clear();
    _fav_appinfos.clear();
    loadAppsInfo();
}
```

to:

```cpp
void AppHandler::reload() {
    qDeleteAll(_fav_appinfos);
    _fav_appinfos.clear();
    qDeleteAll(_appinfos);
    _appinfos.clear();
    loadAppsInfo();
}
```

- [ ] **Step 4: Fix `loadLibertineAppsFromDir` wrong object reference**

In `plugins/AppHandler/apphandler.cpp`, lines 64-81, the code does `AppInfo* app = _appinfos.last()` which gets the wrong object. Refactor the block to capture the newly created AppInfo:

Replace lines 64-81:

```cpp
      AppInfo* app = _appinfos.last();
      qDebug() << "Parsing libertine desktop app:" << fileName << "->" << fileName.left(fileName.size() - QString(".desktop").size()) << "OnlyShowIn:" << app->getProp("OnlyShowIn");
      if(app->getProp("OnlyShowIn") == nullptr) {
        _appinfos.append(new AppInfo(container, fileName.left(fileName.size() - QString(".desktop").size()), filestream.readAll(), true));
        
        if(app->getProp("Icon").startsWith("/")) {
          app->setIcon(HOME_PATH + "/.cache/libertine-container/"+container+"/rootfs"+app->getProp("Icon"));
        }
        else if(QFile(HOME_PATH + "/.cache/libertine-container/"+container+"/rootfs/usr/share/icons/hicolor/128x128/apps/"+app->getProp("Icon")+".png").exists()) {
          app->setIcon(HOME_PATH + "/.cache/libertine-container/"+container+"/rootfs/usr/share/icons/hicolor/128x128/apps/"+app->getProp("Icon")+".png");
        }
        else if(QFile(HOME_PATH + "/.cache/libertine-container/"+container+"/usr/share/icons/hicolor/scalable/apps/"+app->getProp("Icon")+".png").exists()) {
          app->setIcon(HOME_PATH + "/.cache/libertine-container/"+container+"/usr/share/icons/hicolor/scalable/apps/"+app->getProp("Icon")+".png");
        }
        else {
          app->setIcon("image://theme/placeholder-app-icon");
        }
        qDebug() << " libertine desktop app:" << fileName << " added";
      }
```

with:

```cpp
      QString content = filestream.readAll();
      QString appId = fileName.left(fileName.size() - QString(".desktop").size());
      
      // Check OnlyShowIn before creating the AppInfo
      AppInfo tempApp(container, appId, content, true);
      qDebug() << "Parsing libertine desktop app:" << fileName << "->" << appId << "OnlyShowIn:" << tempApp.getProp("OnlyShowIn");
      if(tempApp.getProp("OnlyShowIn") == nullptr) {
        AppInfo* app = new AppInfo(container, appId, content, true);
        _appinfos.append(app);
        
        if(app->getProp("Icon").startsWith("/")) {
          app->setIcon(HOME_PATH + "/.cache/libertine-container/"+container+"/rootfs"+app->getProp("Icon"));
        }
        else if(QFile(HOME_PATH + "/.cache/libertine-container/"+container+"/rootfs/usr/share/icons/hicolor/128x128/apps/"+app->getProp("Icon")+".png").exists()) {
          app->setIcon(HOME_PATH + "/.cache/libertine-container/"+container+"/rootfs/usr/share/icons/hicolor/128x128/apps/"+app->getProp("Icon")+".png");
        }
        else if(QFile(HOME_PATH + "/.cache/libertine-container/"+container+"/usr/share/icons/hicolor/scalable/apps/"+app->getProp("Icon")+".png").exists()) {
          app->setIcon(HOME_PATH + "/.cache/libertine-container/"+container+"/usr/share/icons/hicolor/scalable/apps/"+app->getProp("Icon")+".png");
        }
        else {
          app->setIcon("image://theme/placeholder-app-icon");
        }
        qDebug() << " libertine desktop app:" << fileName << " added";
      }
```

- [ ] **Step 5: Commit**

```bash
git add plugins/AppHandler/apphandler.cpp
git commit -m "fix: memory leaks in AppHandler plugin

- Free AppInfo objects before clearing lists in reload() and clear_appinfo()
- Fix loadLibertineAppsFromDir() to use the newly created AppInfo
  instead of the last element from a previous iteration"
```

---

### Task 2: Fix LibertineLauncher memory leak and blocking

**Files:**
- Modify: `plugins/LibertineLauncher/libertinelauncher.cpp`
- Modify: `plugins/LibertineLauncher/libertineworker.cpp`

**Interfaces:**
- Consumes: None (independent of Task 1)
- Produces: Worker objects properly parented, process waits have timeouts

- [ ] **Step 1: Fix LibertineLauncher to parent the worker**

In `plugins/LibertineLauncher/libertinelauncher.cpp`, change line 13:

```cpp
    LibertineWorker *worker = new LibertineWorker(containerName, appName);
```

to:

```cpp
    LibertineWorker *worker = new LibertineWorker(containerName, appName, this);
```

- [ ] **Step 2: Add timeout to LibertineWorker::run()**

In `plugins/LibertineLauncher/libertineworker.cpp`, line 29, change:

```cpp
        libertineProcess.waitForFinished(-1);// avoid the 30-second timeout
```

to:

```cpp
        libertineProcess.waitForFinished(30000);
```

- [ ] **Step 3: Fix typo in error message**

In `plugins/LibertineLauncher/libertineworker.cpp`, line 23, change:

```cpp
            qDebug() << "Erreur : Failed to start application" << m_appName;
```

to:

```cpp
            qDebug() << "Error: Failed to start application" << m_appName;
```

- [ ] **Step 4: Commit**

```bash
git add plugins/LibertineLauncher/libertinelauncher.cpp plugins/LibertineLauncher/libertineworker.cpp
git commit -m "fix: memory leak and UI blocking in LibertineLauncher

- Parent LibertineWorker to launcher for automatic cleanup
- Add 30s timeout to waitForFinished to prevent indefinite blocking
- Fix French typo in error message"
```

---

### Task 3: Fix nested onClicked bugs in QML pages

**Files:**
- Modify: `qml/pages/Home.qml`
- Modify: `qml/pages/Music.qml`
- Modify: `qml/pages/Picture.qml`
- Modify: `qml/pages/Videos.qml`

**Interfaces:**
- Consumes: None (independent of Tasks 1-2)
- Produces: All onClicked handlers fire correctly

- [ ] **Step 1: Fix Home.qml Cancel button in auth dialog**

In `qml/pages/Home.qml`, lines 57-59, change:

```qml
                    onClicked: {
                        onClicked: PopupUtils.close(authentDialogue);
                    }
```

to:

```qml
                    onClicked: PopupUtils.close(authentDialogue)
```

- [ ] **Step 2: Fix Home.qml Cancel button in apps dialog**

In `qml/pages/Home.qml`, lines 483-485, change:

```qml
                                            onClicked: {
                                                onClicked: PopupUtils.close(appsDialogue);
                                            }
```

to:

```qml
                                            onClicked: PopupUtils.close(appsDialogue)
```

- [ ] **Step 3: Fix Music.qml file click handler**

In `qml/pages/Music.qml`, lines 252-261, change:

```qml
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (!fileIsDir) {
                                    onClicked:Qt.openUrlExternally("music://" + model.filePath)
                                } else {
                                     searchTerm = ""
                                     musicFileModel.folder = model.filePath
                                }
                            }
                        }
```

to:

```qml
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (!fileIsDir) {
                                    Qt.openUrlExternally("music://" + model.filePath)
                                } else {
                                     searchTerm = ""
                                     musicFileModel.folder = model.filePath
                                }
                            }
                        }
```

- [ ] **Step 4: Fix Picture.qml photo click handler**

In `qml/pages/Picture.qml`, lines 72-77, change:

```qml
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        onClicked:Qt.openUrlExternally("photo://" + filePath)
                    }
                }
```

to:

```qml
                MouseArea {
                    anchors.fill: parent
                    onClicked: Qt.openUrlExternally("photo://" + filePath)
                }
```

- [ ] **Step 5: Fix Videos.qml file click handler**

In `qml/pages/Videos.qml`, lines 250-259, change:

```qml
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (!fileIsDir) {
                                    onClicked:Qt.openUrlExternally("video://" + model.filePath)
                                } else {
                                     searchTerm = ""
                                     videoFileModel.folder = model.filePath
                                }
                            }
                        }
```

to:

```qml
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (!fileIsDir) {
                                    Qt.openUrlExternally("video://" + model.filePath)
                                } else {
                                     searchTerm = ""
                                     videoFileModel.folder = model.filePath
                                }
                            }
                        }
```

- [ ] **Step 6: Commit**

```bash
git add qml/pages/Home.qml qml/pages/Music.qml qml/pages/Picture.qml qml/pages/Videos.qml
git commit -m "fix: nested onClicked handlers that never fired

QML pattern 'onClicked: { onClicked: ... }' creates a property
assignment instead of calling the code. Remove the nested 'onClicked:'
in Home.qml (2 locations), Music.qml, Picture.qml, and Videos.qml."
```

---

### Task 4: Fix crashes and UI blocking

**Files:**
- Modify: `qml/ChangeLogs.qml`
- Modify: `qml/Pagemanagement.qml`
- Modify: `plugins/Terminalaccess/terminalaccess.cpp`

**Interfaces:**
- Consumes: None (independent of Tasks 1-3)
- Produces: No crashes on last list item, no UI thread blocking, correct signal emission

- [ ] **Step 1: Fix ChangeLogs.qml out-of-bounds crash**

In `qml/ChangeLogs.qml`, line 240, change:

```qml
                                    color: if (index < changeLogModel.count && changeLogModel.get(index+1).version.length > 0){"#FFFFFF"} else {"#111111"}
```

to:

```qml
                                    color: (index < changeLogModel.count - 1 && changeLogModel.get(index + 1).version.length > 0) ? "#FFFFFF" : "#111111"
```

- [ ] **Step 2: Fix Pagemanagement.qml incorrect visible binding**

In `qml/Pagemanagement.qml`, line 143, change:

```qml
                        visible: if(fileName && fileName.split(".")[0] == "Home"){false; height = 0} else {true}
```

to:

```qml
                        visible: !(fileName && fileName.split(".")[0] === "Home")
```

- [ ] **Step 3: Fix terminalaccess.cpp double signal emission**

In `plugins/Terminalaccess/terminalaccess.cpp`, lines 61-62, change:

```cpp
        emit(needSudoPassword());
        needSudoPassword();
```

to:

```cpp
        emit needSudoPassword();
```

- [ ] **Step 4: Fix terminalaccess.cpp missing emit keyword**

In `plugins/Terminalaccess/terminalaccess.cpp`, line 69, change:

```cpp
        newErrorAvailable();
```

to:

```cpp
        emit newErrorAvailable();
```

- [ ] **Step 5: Fix terminalaccess.cpp indentation bug**

In `plugins/Terminalaccess/terminalaccess.cpp`, lines 18-25, the `_err.clear()` is outside the `if(reset_err)` block due to incorrect indentation. Change:

```cpp
bool Terminalaccess::start(bool reset_err, bool reset_out) {
    _proc.kill();
    _proc.waitForFinished();
    if(reset_err)
    qDebug() << "Process fail to start :" << _proc.readAllStandardError() << _err;
		_err.clear();
    if(reset_out)
		_output.clear();
```

to:

```cpp
bool Terminalaccess::start(bool reset_err, bool reset_out) {
    _proc.kill();
    _proc.waitForFinished(5000);
    if(reset_err) {
        qDebug() << "Process fail to start :" << _proc.readAllStandardError() << _err;
        _err.clear();
    }
    if(reset_out) {
        _output.clear();
    }
```

Note: This also adds the 5000ms timeout to `waitForFinished` (Step 6).

- [ ] **Step 6: Fix terminalaccess.cpp waitForStarted timeout**

In `plugins/Terminalaccess/terminalaccess.cpp`, line 27, change:

```cpp
    if(!_proc.waitForStarted()) {
```

to:

```cpp
    if(!_proc.waitForStarted(5000)) {
```

- [ ] **Step 7: Commit**

```bash
git add qml/ChangeLogs.qml qml/Pagemanagement.qml plugins/Terminalaccess/terminalaccess.cpp
git commit -m "fix: crashes and UI blocking

- ChangeLogs.qml: bounds check before accessing index+1 on last item
- Pagemanagement.qml: fix incorrect visible binding with semicolons
- terminalaccess.cpp: remove double signal emission, add missing emit,
  fix indentation bug, add 5s timeouts to waitForFinished/waitForStarted"
```

---

### Task 5: Verify build

- [ ] **Step 1: Build the project**

```bash
clickable build --arch arm64
```

or for desktop testing:

```bash
clickable desktop
```

- [ ] **Step 2: Manual smoke test**

Verify:
- Launcher starts without crash
- Pull-to-refresh works (triggers AppHandler.reload())
- App context menu → Cancel button works (nested onClicked fix)
- Music/Videos/Picture page file taps work
- Change Logs page scrolls to end without crash
- Terminal commands don't freeze UI

- [ ] **Step 3: Final review and push**

```bash
git log --oneline
git push -u origin fix/critical-bugs
```
