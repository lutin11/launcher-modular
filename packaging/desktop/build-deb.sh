#!/bin/sh
# Build the desktop .deb with CPack (see docs/PACKAGING_DESKTOP.md).
#
# Run inside a container that has the build dependencies (the recipe is
# verified in clickable/amd64-ut24.04-1.x-amd64, Ubuntu 24.04):
#   docker run --rm --entrypoint sh -v "$PWD:/src:ro" -v "$PWD/out:/out" \
#     clickable/amd64-ut24.04-1.x-amd64:latest /src/packaging/desktop/build-deb.sh
#
# $1: source directory (default /src), used read-only: the build happens on a
# copy because update_po_files rewrites po/*.po. $2: output directory
# (default /out) receiving launchermodular-<version>-Linux.deb.
set -e

SRC="${1:-/src}"
OUT="${2:-/out}"

if [ ! -f "$SRC/manifest.json.in" ]; then
    echo "error: no source tree at $SRC. This script must run inside the" >&2
    echo "Clickable SDK container, e.g. from the repository root:" >&2
    echo "  docker run --rm --entrypoint sh -v \"\$PWD\":/src:ro -v \"\$PWD/out:/out\" \\" >&2
    echo "    clickable/amd64-ut24.04-1.x-amd64:latest sh /src/packaging/desktop/build-deb.sh" >&2
    exit 1
fi

BUILD_DIR="$(mktemp -d)/src"
cp -r "$SRC" "$BUILD_DIR"
cd "$BUILD_DIR"

cmake -S . -B build -DDESKTOP_INSTALL=ON
make -C build -j"$(nproc)"
(cd build && cpack -G DEB)

mkdir -p "$OUT"
cp build/*.deb "$OUT"/
# Artifacts are built as root inside the container: hand them back to the
# owner of the source tree (the calling user on the host, the runner in CI).
OWNER="$(stat -c '%u:%g' "$SRC" 2>/dev/null)" && [ -n "$OWNER" ] && chown -R "$OWNER" "$OUT" || true
echo "built: $(ls "$OUT"/*.deb)"
