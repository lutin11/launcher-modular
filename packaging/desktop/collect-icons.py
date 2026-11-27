#!/usr/bin/env python3
"""Collect the themed icons used by the QML into a minimal hicolor theme.

The launcher draws its chrome with ``Icon { name: "back" }``: Lomiri resolves
those names through the session icon theme (Suru on Ubuntu Touch).  A .deb
installed outside a Lomiri session, and the AppImage, have no Suru theme, so
those icons were rendered empty (see VALIDATION_PACKAGES.md, T2/F2/F3).

Instead of shipping the whole Suru theme (tens of megabytes), this script scans
the QML for the icon names actually used and copies the matching files into a
small ``hicolor`` overlay: a few dozen SVG files, a few hundred kilobytes.
``hicolor`` is the fallback theme of every freedesktop system, so the icons are
found even when the session theme is absent.

Usage:
    collect-icons.py --qml <qml-dir> --dest <hicolor-dir> [--index-theme]

--index-theme (used for the AppImage, whose bundled hicolor has no index.theme)
also writes an index.theme listing the directories that contain icons.
"""

import argparse
import os
import re
import shutil
import sys

# Themes searched at build time, best first.  Suru and ubuntu-mobile carry the
# icons Lomiri asks for; hicolor and Adwaita fill the gaps for a few names.
THEME_PRIORITY = ["suru", "ubuntu-mobile", "hicolor", "Adwaita"]

# Contexts of the freedesktop icon theme specification.
CONTEXTS = ("apps", "actions", "status", "devices", "places", "categories",
            "mimetypes", "toolkit", "stock")

# Names Lomiri asks for that the build themes provide under another name.
ALIASES = {
    "image-symbolic": ("image-symbolic", "image-x-generic-symbolic",
                       "image-x-generic"),
}


def icon_names(qml_dir):
    """Icon names referenced by the QML: Icon { name: ... } and iconName: ..."""
    names = set()
    block = re.compile(r"\bIcon\s*\{")
    literal = re.compile(r'"([^"\\]+)"')
    for root, _dirs, files in os.walk(qml_dir):
        for name in files:
            if not name.endswith(".qml"):
                continue
            path = os.path.join(root, name)
            with open(path, encoding="utf-8", errors="replace") as handle:
                source = handle.read()

            for match in re.finditer(r'iconName:\s*"([^"]+)"', source):
                names.add(match.group(1))

            for match in block.finditer(source):
                start = match.end()
                depth = 1
                index = start
                while index < len(source) and depth:
                    if source[index] == "{":
                        depth += 1
                    elif source[index] == "}":
                        depth -= 1
                    index += 1
                body = source[start:index - 1]
                for prop in re.finditer(r"\bname:\s*([^\n]+)", body):
                    value = prop.group(1)
                    # Comparisons in a ternary hold strings that are not icon
                    # names ("horizontal" ? "go-next" : "go-down").
                    value = re.sub(r'[=!]==?\s*"[^"]*"', "", value)
                    # Ternary expressions hold several literals: keep them all,
                    # the ones that do not exist are simply not collected.
                    names.update(literal.findall(value))
    return sorted(names)


def _score(path):
    """Higher is better: scalable beats bitmaps, bigger sizes beat smaller."""
    directory = os.path.dirname(path)
    if directory.endswith("/scalable") or "/scalable/" in directory:
        return (2, 0)
    match = re.search(r"/(\d+)x\d+/", path)
    if match:
        return (1, int(match.group(1)))
    return (0, 0)


def _theme_rank(theme):
    if theme in THEME_PRIORITY:
        return len(THEME_PRIORITY) - THEME_PRIORITY.index(theme)
    return 0


def _icon_roots():
    roots = []
    data_dirs = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share")
    for data_dir in data_dirs.split(":"):
        if data_dir:
            roots.append(os.path.join(data_dir, "icons"))
    roots.append(os.path.expanduser("~/.local/share/icons"))
    roots.append(os.path.expanduser("~/.icons"))
    unique = []
    for root in roots:
        if root not in unique and os.path.isdir(root):
            unique.append(root)
    return unique


def build_index(roots):
    """name -> best icon file, by theme priority then by file quality."""
    index = {}
    for root in roots:
        for theme in sorted(os.listdir(root), key=_theme_rank, reverse=True):
            theme_dir = os.path.join(root, theme)
            if not os.path.isdir(theme_dir) or not os.path.isfile(
                    os.path.join(theme_dir, "index.theme")):
                continue
            for directory, _dirs, files in os.walk(theme_dir):
                for filename in files:
                    base, extension = os.path.splitext(filename)
                    if extension not in (".svg", ".png", ".xpm"):
                        continue
                    if not any(context in directory.split(os.sep)
                               for context in CONTEXTS):
                        continue
                    path = os.path.join(directory, filename)
                    candidate = (_theme_rank(theme), _score(path))
                    if base not in index or candidate > index[base][0]:
                        index[base] = (candidate, path)
    return {name: value[1] for name, value in index.items()}


def install(icon_file, name, dest):
    """Copy one icon to the right hicolor sub-directory, return the relative one."""
    extension = os.path.splitext(icon_file)[1].lower()
    if extension == ".svg":
        relative = os.path.join("scalable", "apps")
    else:
        match = re.search(r"/(\d+)x\d+/", icon_file)
        size = match.group(1) if match else "48"
        relative = os.path.join("%sx%s" % (size, size), "apps")
    target_dir = os.path.join(dest, relative)
    os.makedirs(target_dir, exist_ok=True)
    shutil.copyfile(icon_file, os.path.join(target_dir, name + extension))
    return relative


def write_index_theme(dest):
    """Write a minimal index.theme for the directories that hold icons."""
    directories = []
    for directory, _dirs, files in os.walk(dest):
        if any(f.endswith((".svg", ".png", ".xpm")) for f in files):
            relative = os.path.relpath(directory, dest)
            if relative not in directories:
                directories.append(relative)
    if not directories:
        return
    directories.sort()
    lines = ["[Icon Theme]",
             "Name=Hicolor",
             "Comment=Fallback icon theme with the icons used by launchermodular",
             "Hidden=true",
             "Directories=" + ",".join(directories),
             ""]
    for relative in directories:
        parts = relative.split(os.sep)
        if parts[0] == "scalable":
            size = "48"
            icon_type = "Scalable"
        else:
            match = re.match(r"(\d+)x\d+", parts[0])
            size = match.group(1) if match else "48"
            icon_type = "Fixed"
        # collect-icons.py always installs into the "apps" context.
        lines += ["[%s]" % relative,
                  "Size=%s" % size,
                  "Type=%s" % icon_type,
                  "Context=Applications",
                  ""]
    with open(os.path.join(dest, "index.theme"), "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--qml", help="directory holding the QML files")
    parser.add_argument("--dest", required=True,
                        help="hicolor directory to fill (created if needed)")
    parser.add_argument("--index-theme", action="store_true",
                        help="write index.theme for the icons already in --dest")
    arguments = parser.parse_args()

    if arguments.qml:
        names = icon_names(arguments.qml)
        index = build_index(_icon_roots())
        missing = []
        installed = 0
        for name in names:
            icon_file = None
            for candidate in ALIASES.get(name, (name,)):
                if candidate in index:
                    icon_file = index[candidate]
                    break
            if not icon_file:
                missing.append(name)
                continue
            install(icon_file, name, arguments.dest)
            installed += 1
        print("icons: %d collected, %d unavailable" % (installed, len(missing)))
        if missing:
            print("icons not found in the build themes: " + ", ".join(missing),
                  file=sys.stderr)

    if arguments.index_theme:
        write_index_theme(arguments.dest)

    return 0


if __name__ == "__main__":
    sys.exit(main())
