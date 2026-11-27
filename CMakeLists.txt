cmake_minimum_required(VERSION 3.16)
project(launchermodular C CXX)
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# Qt 5 remains the reference: Ubuntu Touch 24.04 ships Qt 5.15 and the Lomiri
# Qt 6 migration is still in progress (see docs/QT6.md). USE_QT6 prepares a
# Qt 6 build for the day the toolkits are ported.
option(USE_QT6 "Build against Qt 6 instead of Qt 5 (experimental)" OFF)
if(USE_QT6)
    find_package(Qt6 6.2 REQUIRED COMPONENTS Core Gui Qml Quick)
    set(QT_VERSION_MAJOR 6)
else()
    find_package(Qt5 5.12 REQUIRED COMPONENTS Core Gui Qml Quick)
    set(QT_VERSION_MAJOR 5)
endif()
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)


# Automatically create moc files
set(CMAKE_AUTOMOC ON)

set(PROJECT_NAME "launchermodular")
set(FULL_PROJECT_NAME "launchermodular.lut11")
set(DESKTOP_FILE_NAME ${PROJECT_NAME}.desktop)
set(MAIN_SRC_FILES
    windowcontroller.h
    windowcontroller.cpp)

# Components PATH. dpkg-architecture only exists on Debian based systems; there
# CMake also knows the multiarch triplet from the compiler, and elsewhere the
# QML import directory is simply lib/.
find_program(DPKG_ARCHITECTURE dpkg-architecture)
if(DPKG_ARCHITECTURE)
    execute_process(
        COMMAND ${DPKG_ARCHITECTURE} -qDEB_HOST_MULTIARCH
        OUTPUT_VARIABLE ARCH_TRIPLET
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
else()
    set(ARCH_TRIPLET "${CMAKE_LIBRARY_ARCHITECTURE}")
endif()

# Installation layout.
#
# A click package is unpacked in a directory of its own and expects the binary,
# qml/ and assets/ at the root of that directory: that is the historical layout,
# kept as the default. A desktop install (.deb or AppImage) follows the usual
# hierarchy instead; the binary is told where the data and the QML plugins went
# through LAUNCHERMODULAR_DATA_DIR and LAUNCHERMODULAR_IMPORT_DIR (main.cpp).
option(DESKTOP_INSTALL "Install as a system application (.deb or AppImage) rather than a click package" OFF)

if(DESKTOP_INSTALL)
    if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
        set(CMAKE_INSTALL_PREFIX "/usr" CACHE PATH "Install prefix" FORCE)
    endif()
    set(BIN_DIR "bin")
    set(DATA_DIR "share/${PROJECT_NAME}")
    set(PLUGIN_IMPORT_DIR "lib/${ARCH_TRIPLET}/${PROJECT_NAME}")
    set(DESKTOP_FILE_DIR "share/applications")
    set(APP_DATA_PATH "${CMAKE_INSTALL_PREFIX}/${DATA_DIR}")
    set(APP_IMPORT_PATH "${CMAKE_INSTALL_PREFIX}/lib/${ARCH_TRIPLET}/${PROJECT_NAME}")
else()
    set(CMAKE_INSTALL_PREFIX /)
    set(BIN_DIR /)
    set(DATA_DIR /)
    set(PLUGIN_IMPORT_DIR "lib/${ARCH_TRIPLET}")
    set(DESKTOP_FILE_DIR /)
    set(APP_DATA_PATH "/")
    set(APP_IMPORT_PATH "/lib/${ARCH_TRIPLET}")
endif()

# The click package metadata: manifest, AppArmor profile and content hub
# definition are only meaningful for a click package.
if(DESKTOP_INSTALL)
    option(INSTALL_CLICK_FILES "Install manifest.json, the AppArmor profile and the content hub definition" OFF)
else()
    option(INSTALL_CLICK_FILES "Install manifest.json, the AppArmor profile and the content hub definition" ON)
endif()

# The architecture written in the manifest file, only used by the click package
if(DPKG_ARCHITECTURE)
    execute_process(
        COMMAND ${DPKG_ARCHITECTURE} -qDEB_HOST_ARCH
        OUTPUT_VARIABLE CLICK_ARCH
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
else()
    set(CLICK_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
endif()

add_definitions(-D__ARCH_TRIPLET__="${ARCH_TRIPLET}")
add_definitions(-DLAUNCHERMODULAR_DATA_DIR="${APP_DATA_PATH}")
add_definitions(-DLAUNCHERMODULAR_IMPORT_DIR="${APP_IMPORT_PATH}")
add_executable(${PROJECT_NAME} main.cpp ${MAIN_SRC_FILES})
target_link_libraries(${PROJECT_NAME} Qt${QT_VERSION_MAJOR}::Gui Qt${QT_VERSION_MAJOR}::Qml Qt${QT_VERSION_MAJOR}::Quick)
install(TARGETS ${PROJECT_NAME} RUNTIME DESTINATION ${BIN_DIR})


if(INSTALL_CLICK_FILES)
    configure_file(manifest.json.in ${CMAKE_CURRENT_BINARY_DIR}/manifest.json)
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/manifest.json DESTINATION ${CMAKE_INSTALL_PREFIX})
    install(FILES ${PROJECT_NAME}.apparmor DESTINATION ${DATA_DIR})
    install(FILES ${PROJECT_NAME}.contenthub DESTINATION ${DATA_DIR})
endif()
install(DIRECTORY qml DESTINATION ${DATA_DIR})
install(DIRECTORY assets DESTINATION ${DATA_DIR})

# Translations
file(GLOB_RECURSE I18N_SRC_FILES RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} qml/*.qml qml/*.js)
list(APPEND I18N_SRC_FILES ${DESKTOP_FILE_NAME}.in.h)

find_program(INTLTOOL_MERGE intltool-merge)
if(NOT INTLTOOL_MERGE)
    message(FATAL_ERROR "Could not find intltool-merge, please install the intltool package")
endif()
find_program(INTLTOOL_EXTRACT intltool-extract)
if(NOT INTLTOOL_EXTRACT)
    message(FATAL_ERROR "Could not find intltool-extract, please install the intltool package")
endif()

# Include fonts
set(RESOURCE_FILES "${CMAKE_CURRENT_SOURCE_DIR}/resources.qrc")
# qt_add_resources is the Qt 5.15+/Qt 6 command; Qt 5.12 only has qt5_add_resources.
if(COMMAND qt_add_resources)
    qt_add_resources(Resources ${RESOURCE_FILES})
else()
    qt5_add_resources(Resources ${RESOURCE_FILES})
endif()
target_sources(${PROJECT_NAME} PRIVATE main.cpp ${Resources})

# The .desktop file shipped for the click package refers to the icon by a path
# relative to the application directory. A system install uses a themed icon
# name instead, and installs the artwork where the icon theme looks.
set(DESKTOP_POST_COMMANDS "")
if(DESKTOP_INSTALL)
    list(APPEND DESKTOP_POST_COMMANDS
        COMMAND ${CMAKE_COMMAND}
                -DDESKTOP_FILE=${CMAKE_CURRENT_BINARY_DIR}/${DESKTOP_FILE_NAME}
                -DICON_NAME=${PROJECT_NAME}
                -P ${CMAKE_SOURCE_DIR}/cmake/SetDesktopIcon.cmake)
endif()

add_custom_target(${DESKTOP_FILE_NAME} ALL
    COMMENT "Merging translations into ${DESKTOP_FILE_NAME}..."
    COMMAND LC_ALL=C ${INTLTOOL_MERGE} -d -u ${CMAKE_SOURCE_DIR}/po ${CMAKE_SOURCE_DIR}/${DESKTOP_FILE_NAME}.in ${DESKTOP_FILE_NAME}
    COMMAND sed -i 's/${PROJECT_NAME}-//g' ${CMAKE_CURRENT_BINARY_DIR}/${DESKTOP_FILE_NAME}
    ${DESKTOP_POST_COMMANDS}
)

install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${DESKTOP_FILE_NAME} DESTINATION ${DESKTOP_FILE_DIR})
if(DESKTOP_INSTALL)
    # hicolor is the standard location, pixmaps is found without an icon cache
    # having been refreshed, which a package built without debhelper cannot do.
    install(FILES assets/logo.svg DESTINATION share/icons/hicolor/scalable/apps RENAME ${PROJECT_NAME}.svg)
    install(FILES assets/logo.svg DESTINATION share/pixmaps RENAME ${PROJECT_NAME}.svg)

    # The chrome of the application (back arrows, delete, media controls…) is
    # drawn with Icon { name: … }: those names are resolved through the session
    # icon theme, Suru on Ubuntu Touch, which a plain desktop does not have.
    # Collect the icons actually used by the QML from the themes of the build
    # machine (a few hundred kilobytes) instead of depending on the whole
    # theme; see packaging/desktop/collect-icons.py and VALIDATION_PACKAGES.md.
    find_package(Python3 COMPONENTS Interpreter QUIET)
    if(Python3_Interpreter_FOUND)
        file(GLOB_RECURSE DESKTOP_QML_FILES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/qml/*.qml")
        set(DESKTOP_ICON_STAGE "${CMAKE_CURRENT_BINARY_DIR}/desktop-icons")
        add_custom_command(
            OUTPUT "${DESKTOP_ICON_STAGE}/.stamp"
            COMMAND ${CMAKE_COMMAND} -E rm -rf "${DESKTOP_ICON_STAGE}"
            COMMAND ${Python3_EXECUTABLE}
                    "${CMAKE_CURRENT_SOURCE_DIR}/packaging/desktop/collect-icons.py"
                    --qml "${CMAKE_CURRENT_SOURCE_DIR}/qml"
                    --dest "${DESKTOP_ICON_STAGE}"
            COMMAND ${CMAKE_COMMAND} -E touch "${DESKTOP_ICON_STAGE}/.stamp"
            DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/packaging/desktop/collect-icons.py"
                    ${DESKTOP_QML_FILES}
            COMMENT "Collecting the themed icons used by the QML"
            VERBATIM)
        add_custom_target(desktop_icons ALL DEPENDS "${DESKTOP_ICON_STAGE}/.stamp")
        install(DIRECTORY "${DESKTOP_ICON_STAGE}/" DESTINATION share/icons/hicolor
                PATTERN ".stamp" EXCLUDE)
    else()
        message(WARNING "python3 not found: the themed icons used by the QML "
                        "will not be installed, Icon { name: … } may stay empty")
    endif()
endif()

add_subdirectory(po)
add_subdirectory(plugins)

# Make source files visible in qtcreator
# We don't need to add plugin sources here as they get exposed
# via the library target.
file(GLOB_RECURSE PROJECT_SRC_FILES
    RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
    qml/*.qml
    qml/*.js
    *.json
    *.json.in
    *.apparmor
    *.desktop.in
)

add_custom_target(${PROJECT_NAME}_FILES ALL SOURCES ${PROJECT_SRC_FILES})

# ---------------------------------------------------------------------------
# Desktop package (.deb)
#
# CPack builds the package from the install tree and needs no debhelper, so it
# also works inside the Clickable container. Run it after a build configured
# with -DDESKTOP_INSTALL=ON:
#   cmake -DDESKTOP_INSTALL=ON .. && cpack -G DEB
# The version, description and maintainer are read from manifest.json.in so
# that the release stays declared in one place (see AGENTS.md rule 8).
# ---------------------------------------------------------------------------
if(DESKTOP_INSTALL)
    file(READ "${CMAKE_CURRENT_SOURCE_DIR}/manifest.json.in" MANIFEST_JSON)
    string(REGEX MATCH "\"version\": *\"[^\"]+\"" _ "${MANIFEST_JSON}")
    string(REGEX REPLACE "\"version\": *\"([^\"]+)\"" "\\1" APP_VERSION "${CMAKE_MATCH_0}")
    string(REGEX MATCH "\"description\": *\"[^\"]+\"" _ "${MANIFEST_JSON}")
    string(REGEX REPLACE "\"description\": *\"([^\"]+)\"" "\\1" APP_DESCRIPTION "${CMAKE_MATCH_0}")
    string(REGEX MATCH "\"maintainer\": *\"[^\"]+\"" _ "${MANIFEST_JSON}")
    string(REGEX REPLACE "\"maintainer\": *\"([^\"]+)\"" "\\1" APP_MAINTAINER "${CMAKE_MATCH_0}")

    set(CPACK_PACKAGE_NAME ${PROJECT_NAME})
    set(CPACK_PACKAGE_VERSION ${APP_VERSION})
    set(CPACK_PACKAGE_DESCRIPTION_SUMMARY ${APP_DESCRIPTION})
    set(CPACK_PACKAGE_DESCRIPTION "A full screen launcher for Lomiri: configurable pages, widgets and application shortcuts.")
    set(CPACK_PACKAGE_HOMEPAGE_URL "https://github.com/lutin11/launcher-modular")
    set(CPACK_PACKAGE_CONTACT "${APP_MAINTAINER}")
    set(CPACK_DEBIAN_PACKAGE_MAINTAINER "${APP_MAINTAINER}")
    set(CPACK_DEBIAN_PACKAGE_SECTION "x11")
    set(CPACK_DEBIAN_PACKAGE_PRIORITY "optional")

    # Every module below was matched to the file that provides it, inside
    # clickable/amd64-ut24.04-1.x-amd64 (dpkg -S) and to a published candidate
    # in Ubuntu 24.04 (apt-cache policy). These are the imports the application
    # cannot start without, Lomiri.Components being loaded by Main.qml itself.
    set(CPACK_DEBIAN_PACKAGE_DEPENDS
        "qml-module-lomiri-components, qml-module-qtquick2, qml-module-qtquick-window2, qml-module-qtquick-controls2, qml-module-qtquick-templates2, qml-module-qtquick-layouts, qml-module-qtquick-xmllistmodel, qml-module-qt-labs-folderlistmodel, qml-module-qt-labs-settings, qml-module-qtgraphicaleffects")
    # Each of these only feeds one removable feature: the application detects
    # what is missing and leaves the feature out of the composition instead of
    # failing (docs/PACKAGING_DESKTOP.md, section 10).
    set(CPACK_DEBIAN_PACKAGE_RECOMMENDS
        "libqt5multimedia5-plugins, lomiri-app-launch, qml-module-qtmultimedia, qml-module-qtsensors, qml-module-qtsysteminfo, qml-module-qtquick-localstorage, qml-module-lomiri-thumbnailer, qml-module-lomiri-content, qml-module-lomiri-downloadmanager, qml-module-lomiri-connectivity, qml-module-lomiri-history, qml-module-u1db")
    # QtContacts and QtOrganizer are only useful together with a provider
    # (galera, eds, sqlite); without one the widgets are left out.
    # qml-module-lomiri-contacts is suggested, not recommended on purpose: apt
    # installs recommendations by default, and that module is not published in
    # the Ubuntu 24.04 archive (section 4.2), so recommending it would make the
    # package impossible to install without a PPA.
    set(CPACK_DEBIAN_PACKAGE_SUGGESTS
        "qml-module-qtcontacts, qml-module-qtorganizer, qml-module-lomiri-contacts")

    set(CPACK_GENERATOR "DEB")
    include(CPack)
endif()
