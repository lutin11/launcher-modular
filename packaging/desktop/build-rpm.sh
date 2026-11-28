#!/bin/sh
# Build a Mageia RPM from the desktop AppImage.
#
# Mageia does not package the Lomiri QML modules, so the RPM cannot be a
# normal source build: it installs the self-contained runtime already built
# for the AppImage under /opt/launchermodular, with a wrapper and a desktop
# entry. The AppImage must have been built first.
#
# Run inside a Mageia container with rpm-build installed, for example:
#   docker run --rm -v "$PWD:/src:ro" -v "$PWD/out:/out" mageia:10 \
#     bash -c 'dnf install -y rpm-build tar gzip && \
#              /src/packaging/desktop/build-rpm.sh /src /out'
#
# $1: source directory (default /src)
# $2: output directory receiving the RPM (default /out)
# $3: AppImage path (default: $OUT/Launcher_Modular-<version>-<arch>.AppImage)
set -e

SRC="${1:-/src}"
OUT="${2:-/out}"

if [ ! -f "$SRC/manifest.json.in" ]; then
    echo "error: no source tree at $SRC (manifest.json.in not found)" >&2
    exit 1
fi

VERSION="$(grep -o '"version": *"[^"]*"' "$SRC/manifest.json.in" \
           | sed 's/.*"\([0-9][^"]*\)"$/\1/')"
ARCH="${ARCH:-$(uname -m)}"
APPIMAGE="${3:-$OUT/Launcher_Modular-$VERSION-$ARCH.AppImage}"

if [ ! -f "$APPIMAGE" ]; then
    echo "error: AppImage not found: $APPIMAGE" >&2
    echo "Build it first with packaging/desktop/build-appimage.sh." >&2
    exit 1
fi
if ! command -v rpmbuild >/dev/null 2>&1; then
    echo "error: rpmbuild is not installed (Mageia: dnf install rpm-build)" >&2
    exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# The AppImage is extracted rather than mounted: the RPM must not depend on
# FUSE, and the bundle is installed as a normal tree under /opt.
cp "$APPIMAGE" "$WORK/launchermodular.AppImage"
chmod +x "$WORK/launchermodular.AppImage"
(cd "$WORK" && ./launchermodular.AppImage --appimage-extract >/dev/null)
if [ ! -d "$WORK/squashfs-root" ]; then
    echo "error: AppImage extraction failed" >&2
    exit 1
fi

mkdir -p "$WORK/src/launchermodular-$VERSION"
cp -a "$WORK/squashfs-root/." "$WORK/src/launchermodular-$VERSION/"
[ -f "$SRC/LICENSE" ] && cp "$SRC/LICENSE" "$WORK/src/launchermodular-$VERSION/"

mkdir -p "$WORK/rpmbuild"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
tar -C "$WORK/src" -czf \
    "$WORK/rpmbuild/SOURCES/launchermodular-appdir-$VERSION.tar.gz" \
    "launchermodular-$VERSION"

# Keep the spec version in sync with manifest.json.in.
sed "s/^Version:.*/Version:        $VERSION/" \
    "$SRC/packaging/rpm/launchermodular.spec" \
    > "$WORK/rpmbuild/SPECS/launchermodular.spec"

rpmbuild --define "_topdir $WORK/rpmbuild" -bb \
    "$WORK/rpmbuild/SPECS/launchermodular.spec"

mkdir -p "$OUT"
find "$WORK/rpmbuild/RPMS" -name '*.rpm' -exec cp -f {} "$OUT"/ \;

OWNER="$(stat -c '%u:%g' "$SRC" 2>/dev/null)" && [ -n "$OWNER" ] \
    && chown -R "$OWNER" "$OUT" || true

echo "built: $(ls "$OUT"/*.rpm 2>/dev/null | tr '\n' ' ')"
