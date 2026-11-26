# Normalizes the .desktop file of a desktop install.
#
# Used by a desktop install only. The click package keeps the value written in
# launchermodular.desktop.in, a path relative to the application directory.
# A CMake script is used rather than sed because the icon pattern contains
# characters the shell would interpret.
#
# - Icon: rewritten to a themed icon name (the click value is a relative path).
# - Categories: added when missing, because packagers reject a desktop file
#   without it (appimagetool errors out, lintian warns) while the click launcher
#   does not use this key.
#
# Usage: cmake -DDESKTOP_FILE=<file> -DICON_NAME=<name> -P SetDesktopIcon.cmake

if(NOT DEFINED DESKTOP_FILE OR NOT DEFINED ICON_NAME)
    message(FATAL_ERROR
        "Usage: cmake -DDESKTOP_FILE=<desktop file> -DICON_NAME=<icon name> -P SetDesktopIcon.cmake")
endif()

file(READ "${DESKTOP_FILE}" CONTENTS)
string(REGEX REPLACE "Icon=[^\n]*" "Icon=${ICON_NAME}" CONTENTS "${CONTENTS}")
if(NOT CONTENTS MATCHES "Categories=")
    string(REGEX REPLACE "(Icon=[^\n]*)" "\\1\nCategories=Utility;" CONTENTS "${CONTENTS}")
endif()
file(WRITE "${DESKTOP_FILE}" "${CONTENTS}")
