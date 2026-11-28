#!/bin/sh
# Build the desktop AppImage (see docs/PACKAGING_DESKTOP.md, section 9).
#
# Recipe verified in clickable/amd64-ut24.04-1.x-amd64 (Ubuntu 24.04, Qt 5.15)
# with linuxdeploy + linuxdeploy-plugin-qt + appimagetool (go-appimage).
#   docker run --rm --entrypoint sh \
#     -v "$PWD:/src:ro" -v "$PWD/.ci-tools:/tools:ro" -v "$PWD/out:/out" \
#     clickable/amd64-ut24.04-1.x-amd64:latest /src/packaging/desktop/build-appimage.sh
#
# $1: source directory (default /src, read-only: the build runs on a copy).
# $2: output directory (default /out) receiving the .AppImage.
# $3: directory holding linuxdeploy-x86_64.AppImage,
#     linuxdeploy-plugin-qt-x86_64.AppImage and appimagetool-x86_64.AppImage
#     (default /tools).
#
# Notes:
#  - the tools run with --appimage-extract-and-run (no FUSE in containers);
#  - the plugin qt scans the whole AppDir for QML files, so the modules
#    imported by share/launchermodular/qml (Lomiri.*, QtContacts, U1db, the
#    Suru style...) are deployed to usr/qml along with their dependencies;
#  - INCLUDE_TEST_PLATFORMS=1 also copies the offscreen/minimal/vnc platform
#    plugins and runs a headless start-up test from the extracted image:
#    CI-only, useful because FUSE mounts cannot be tested in a container.
set -e

SRC="${1:-/src}"
OUT="${2:-/out}"
TOOLS="${3:-/tools}"

if [ ! -f "$SRC/manifest.json.in" ]; then
    echo "error: no source tree at $SRC. This script must run inside the" >&2
    echo "Clickable SDK container, with the AppImage tools mounted at /tools" >&2
    echo "(see docs/PACKAGING_WORKLOG.md, section 6, or .github/workflows/desktop.yml)." >&2
    exit 1
fi

ARCH="${ARCH:-x86_64}"
VERSION="$(grep -o '"version": *"[^"]*"' "$SRC/manifest.json.in" | sed 's/.*"\([0-9][^"]*\)"$/\1/')"
export ARCH VERSION APPIMAGE_EXTRACT_AND_RUN=1

WORK="$(mktemp -d)"
BUILD_DIR="$WORK/src"
APPDIR="$WORK/AppDir"
cp -r "$SRC" "$BUILD_DIR"
cd "$BUILD_DIR"

cmake -S . -B build -DDESKTOP_INSTALL=ON "-DCMAKE_INSTALL_PREFIX=$APPDIR/usr"
make -C build -j"$(nproc)"
make -C build install

# Qt SQL: the RSS page stores its feeds with QtQuick.LocalStorage, whose SQLite
# driver is a Qt plugin that linuxdeploy does not pick up on its own (it is
# loaded at run time, not linked). Copied before linuxdeploy runs so that its
# own dependencies (libQt5Sql…) are deployed with it.
SQL_PLUGIN="$(qmake -query QT_INSTALL_PLUGINS)/sqldrivers/libqsqlite.so"
if [ -f "$SQL_PLUGIN" ]; then
    mkdir -p "$APPDIR/usr/plugins/sqldrivers"
    cp "$SQL_PLUGIN" "$APPDIR/usr/plugins/sqldrivers/"
fi

# QtMultimedia: the GStreamer media service is loaded at run time and
# linuxdeploy does not deploy it, so Audio/MediaPlayer had no backend in the
# AppImage. Copy the service and the Qt Multimedia helper libraries it needs;
# the GStreamer runtime and the codecs stay those of the host, as for a normal
# desktop install (a .deb Recommends libqt5multimedia5-plugins for the same
# reason).
MEDIA_PLUGINS="$(qmake -query QT_INSTALL_PLUGINS)/mediaservice"
QT_LIBS="$(qmake -query QT_INSTALL_LIBS)"
if [ -d "$MEDIA_PLUGINS" ]; then
    mkdir -p "$APPDIR/usr/plugins/mediaservice"
    for f in libgstmediaplayer.so libgstaudiodecoder.so; do
        [ -f "$MEDIA_PLUGINS/$f" ] && cp "$MEDIA_PLUGINS/$f" "$APPDIR/usr/plugins/mediaservice/"
    done
    for lib in libQt5MultimediaGstTools.so.5 libQt5MultimediaWidgets.so.5 \
               libQt5Widgets.so.5; do
        [ -f "$QT_LIBS/$lib" ] && cp "$QT_LIBS/$lib" "$APPDIR/usr/lib/"
    done
fi

# The icons collected by CMake land in usr/share/icons/hicolor, but the bundle
# has no index.theme: without it Qt cannot enumerate the theme and every
# Icon { name: … } stays empty. Generated here, for the AppImage only (a .deb
# uses the index.theme of the system hicolor theme).
if [ -d "$APPDIR/usr/share/icons/hicolor" ] && command -v python3 >/dev/null 2>&1; then
    python3 "$BUILD_DIR/packaging/desktop/collect-icons.py" \
        --dest "$APPDIR/usr/share/icons/hicolor" --index-theme
fi

# AppDir root: the desktop file installed under usr/share/applications is
# already themed (cmake/SetDesktopIcon.cmake) and valid for packagers.
cp assets/logo.svg "$APPDIR/launchermodular.svg"
cp "$APPDIR/usr/share/applications/LauncherModular.desktop" "$APPDIR/LauncherModular.desktop"

# The tools may sit on a read-only mount (/tools in CI): copy them to the
# writable workspace before chmod.
TOOLS_WORK="$WORK/tools"
mkdir -p "$TOOLS_WORK"
cp "$TOOLS"/*.AppImage "$TOOLS_WORK/"
chmod +x "$TOOLS_WORK"/*.AppImage

"$TOOLS_WORK/linuxdeploy-x86_64.AppImage" \
    --appdir="$APPDIR" \
    --plugin=qt \
    --desktop-file="$APPDIR/LauncherModular.desktop" \
    --icon-file="$APPDIR/launchermodular.svg" \
    --custom-apprun="$SRC/packaging/desktop/AppRun"

# The multimedia media service made linuxdeploy bundle libgstreamer, its core
# libraries and GLib from the build image, but not the GStreamer *plugins*.
# A host's plugins are built against the host GStreamer/GLib and refuse to load
# against the older bundled runtime (observed: no "playbin"/"fakesink").
# Keep the host GStreamer and GLib, as a normal desktop install does; they are
# standard on Debian, Ubuntu, Mint and Mageia. The .deb uses them as well.
for f in "$APPDIR"/usr/lib/libgstreamer-1.0.so* \
         "$APPDIR"/usr/lib/libgst*.so* \
         "$APPDIR"/usr/lib/libglib-2.0.so* \
         "$APPDIR"/usr/lib/libgobject-2.0.so* \
         "$APPDIR"/usr/lib/libgio-2.0.so* \
         "$APPDIR"/usr/lib/libgmodule-2.0.so* \
         "$APPDIR"/usr/lib/libmount.so* \
         "$APPDIR"/usr/lib/libblkid.so* \
         "$APPDIR"/usr/lib/libselinux.so* \
         "$APPDIR"/usr/lib/libcrypto.so* \
         "$APPDIR"/usr/lib/libssl.so*; do
    [ -e "$f" ] && rm -f "$f"
done

if [ "${INCLUDE_TEST_PLATFORMS:-0}" = "1" ]; then
    # The continuous linuxdeploy-plugin-qt does not split
    # EXTRA_PLATFORM_PLUGINS; copy the files, their dependencies
    # (libQt5Gui/libQt5Core) are already deployed.
    PLAT="$(qmake -query QT_INSTALL_PLUGINS)/platforms"
    for f in libqoffscreen.so libqminimal.so libqvnc.so; do
        [ -f "$PLAT/$f" ] && cp "$PLAT/$f" "$APPDIR/usr/plugins/platforms/"
    done
fi

# appimagetool writes the .AppImage next to the working directory, so run it
# from $WORK where $APPDIR lives.
cd "$WORK"
"$TOOLS_WORK/appimagetool-x86_64.AppImage" "$APPDIR"
AI="$(ls "$WORK"/Launcher_Modular-*.AppImage | head -1)"
echo "built: $AI"

if [ "${INCLUDE_TEST_PLATFORMS:-0}" = "1" ]; then
    # Start-up test from the extracted image (no FUSE in containers): the
    # AppRun must export APPDIR, and no QML module may be reported missing.
    # A crash after the start-up messages is expected in a container without
    # a Lomiri session; only the greps below are meaningful.
    XDIR="$WORK/extract"
    mkdir -p "$XDIR"
    (cd "$XDIR" && "$AI" --appimage-extract > /dev/null 2>&1) || true
    [ -d "$XDIR/squashfs-root" ] || mv "$PWD/squashfs-root" "$XDIR/squashfs-root"
    RT="$(mktemp -d)"; chmod 700 "$RT"
    RUN_LOG="$WORK/run.log"
    XDG_RUNTIME_DIR="$RT" QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
        timeout 40 dbus-run-session -- "$XDIR/squashfs-root/AppRun" > "$RUN_LOG" 2>&1 || true
    echo "--- run log: $(wc -l < "$RUN_LOG") lines ---"
    if grep -qiE "is not installed|module .*not " "$RUN_LOG"; then
        echo "FAIL: missing QML module"; grep -iE "is not installed" "$RUN_LOG" | head -5; exit 1
    fi
    if grep -qiE "qml/Main\.qml not found|Main\.qml: No such file" "$RUN_LOG"; then
        echo "FAIL: data not resolved"; exit 1
    fi
    if ! grep -qiE "Font to load" "$RUN_LOG"; then
        echo "FAIL: application did not start"; exit 1
    fi
    echo "start-up test: ok"
    cp "$RUN_LOG" "$OUT/appimage-run.log" || true
fi

mkdir -p "$OUT"
cp "$AI" "$OUT"/
# Artifacts are built as root inside the container: hand them back to the
# owner of the source tree (the calling user on the host, the runner in CI).
OWNER="$(stat -c '%u:%g' "$SRC" 2>/dev/null)" && [ -n "$OWNER" ] && chown -R "$OWNER" "$OUT" || true
echo "artifacts: $(ls "$OUT")"
