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

# AppDir root: the desktop file installed under usr/share/applications is
# already themed (cmake/SetDesktopIcon.cmake) and valid for packagers.
cp assets/logo.svg "$APPDIR/launchermodular.svg"
cp "$APPDIR/usr/share/applications/launchermodular.desktop" "$APPDIR/launchermodular.desktop"

# The tools may sit on a read-only mount (/tools in CI): copy them to the
# writable workspace before chmod.
TOOLS_WORK="$WORK/tools"
mkdir -p "$TOOLS_WORK"
cp "$TOOLS"/*.AppImage "$TOOLS_WORK/"
chmod +x "$TOOLS_WORK"/*.AppImage

"$TOOLS_WORK/linuxdeploy-x86_64.AppImage" \
    --appdir="$APPDIR" \
    --plugin=qt \
    --desktop-file="$APPDIR/launchermodular.desktop" \
    --icon-file="$APPDIR/launchermodular.svg" \
    --custom-apprun="$SRC/packaging/desktop/AppRun"

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
echo "artifacts: $(ls "$OUT")"
