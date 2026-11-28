# Qt 5 today, Qt 6 preparation

Launcher Modular is primarily an Ubuntu Touch / Lomiri application. The
reference framework of this branch, `ubuntu-touch-24.04-1.x`, ships **Qt 5.15**
and **Lomiri.Components 1.3**. Qt 6 is therefore a preparation target, not a
build target yet: Lomiri's own Qt 6 migration is still in progress (UBports
roadmap: "the Qt 6 migration will be an ongoing process" around Q1 2026;
lomiri-ui-toolkit Qt 6 port: merge request !94, issue #52).

The code is kept buildable with Qt 5.12+ and Qt 5.15. Everything described
below as "ready" has been written so that it does not depend on Qt 5-only C++
APIs or on a Qt 6-incompatible build system.

## What is already Qt 6-compatible

- **CMake**: `-DUSE_QT6=ON` selects Qt 6 (default is Qt 5). Targets use
  `Qt${QT_VERSION_MAJOR}::…`, resources use `qt_add_resources` when available
  and `qt5_add_resources` otherwise. See the top of `CMakeLists.txt`.
- **C++ standard**: C++17, required by Qt 6.
- **C++ APIs**: the plugins use Core/Gui/Qml/Quick/DBus/Network APIs that still
  exist in Qt 6. `QTextStream::setCodec()` (removed in Qt 6) is guarded and
  replaced by `setEncoding(QStringConverter::Utf8)` under Qt 6 in
  `plugins/AppHandler/apphandler.cpp`.
- **QML imports with a version**: `import QtQuick 2.12` and
  `import QtQuick.Controls 2.2` remain valid in Qt 6 (versioned imports are
  still accepted; they only expose the types of that version). They do not
  need to become versionless for a Qt 5 + Qt 6 build.
- **`Qt.labs.settings` and `Qt.labs.folderlistmodel`**: present in Qt 6.
  `Qt.labs.settings` is deprecated since Qt 6.5 but still available.

## Blockers before a Qt 6 build can run

| Area | Current use | Qt 6 situation | Work needed |
|---|---|---|---|
| Lomiri | `Lomiri.Components 1.3`, ListItems, Popups, Themes, Thumbnailer, Content, DownloadManager, Connectivity, History, Contacts | Qt 6 port in progress in lomiri-ui-toolkit | Wait for the Qt 6 imports, then port the import lines; this gates the whole application |
| Graphical effects | `QtGraphicalEffects 1.12` (25 QML files, e.g. `qml/Main.qml` FastBlur) | Module removed; provided as `Qt5Compat.GraphicalEffects`, or replaced by `MultiEffect` | Add Qt5Compat and change imports, or replace the effects. A single file cannot import both names; do it with the Qt 6 build |
| Multimedia | `QtMultimedia 5.12`, `Audio` type (`qml/pages/music/MusicPlayer.qml`) | `Audio` removed; `MediaPlayer` + `AudioOutput`; playlist API removed | Rewrite the player against the Qt 6 multimedia API |
| XML models | `QtQuick.XmlListModel 2.12` (RSS: 5 files, Weather widget) | Moved to `QtQml.XmlListModel` | Change the import and test the models |
| PIM | `QtOrganizer 5.0`, `QtContacts 5.0` (Calendar page, contacts widgets, ContactHelper plugin) | No Qt 6 PIM module yet | Keep those pages optional (`PageRequirements.js`); `ContactHelper` is skipped when `QT_VERSION_MAJOR` is 6 |
| System info | `QtSystemInfo 5.0` (screen saver in the music player) | Not in Qt 6 | Replace with the platform service (Lomiri) when porting |

`QtQuick.Controls 2.2` is imported unaliased in `qml/Main.qml`, which shadows
Lomiri types such as `Label` (`fontSize`). This is independent of Qt 6 but
should be fixed during the port by importing it as `QControls`.

## Procedure when Lomiri Qt 6 is available

1. Configure with `cmake -DUSE_QT6=ON` and fix the remaining C++ errors
   (the plugins are already written for both).
2. Port the QML imports module by module, starting with the blockers above;
   keep the Qt 5 build green at every step.
3. Test on a desktop Lomiri session first, then on a device: the QML modules
   are resolved at runtime and CI only compiles.
4. Only then change the reference framework and `clickable.yaml`.

## Sources (consulted 2026-11-27)

- Qt 6 porting guide: <https://doc.qt.io/qt-6/portingguide.html>
- Qt 5 / Qt 6 CMake compatibility:
  <https://doc.qt.io/qt-6/cmake-qt5-and-qt6-compatibility.html>
- Changes to Qt Quick in Qt 6: <https://doc.qt.io/qt-6/quick-changes-qt6.html>
- Changes to Qt Multimedia in Qt 6:
  <https://doc.qt.io/qt-6/qtmultimedia-changes-qt6.html>
- Qt Graphical Effects compatibility:
  <https://doc.qt.io/qt-6/graphicaleffects5.html>
- Qt Qml XmlListModel (Qt 6):
  <https://doc.qt.io/qt-6/qml-xmllistmodel.html>
- UBports roadmap (Lomiri, Qt 6 migration): <https://ubports.com/lomiri-roadmap>
- lomiri-ui-toolkit Qt 6 port:
  <https://gitlab.com/ubports/development/core/lomiri-ui-toolkit/-/merge_requests/94>
  and <https://gitlab.com/ubports/development/core/lomiri-ui-toolkit/-/issues/52>
- Ubuntu Touch 24.04-1.x uses Qt 5.15:
  <https://forums.ubports.com/topic/10899/status-update-on-ubuntu-touch-24-04-1-x-march-april-2025>
