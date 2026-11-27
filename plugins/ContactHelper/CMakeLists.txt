set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# The top-level build sets this; keep a standalone configure working on Qt 5.
if(NOT DEFINED QT_VERSION_MAJOR)
    set(QT_VERSION_MAJOR 5)
endif()

# Qt 6 has no Qt PIM (Organizer/Contacts) module yet: the plugin is only
# built against Qt 5 until one exists (see docs/QT6.md).
if(QT_VERSION_MAJOR EQUAL 6)
    message(STATUS "ContactHelper: Qt 6 Contacts not available, plugin skipped")
    return()
endif()

# Define the plugin name
set(PLUGIN "ContactHelper")

# Specify source files
set(
    SRC
    plugin.cpp
    contacthelper.cpp
)

# Enable automatic MOC (Meta-Object Compiler) for Qt
set(CMAKE_AUTOMOC ON)

# Find the required Qt modules, including Contacts
find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Qml Quick DBus Contacts)

# Add the plugin as a module
add_library(${PLUGIN} MODULE ${SRC})

# Set library output directory
set_target_properties(${PLUGIN} PROPERTIES LIBRARY_OUTPUT_DIRECTORY ${PLUGIN})

# Link the necessary Qt modules to the plugin target
target_link_libraries(${PLUGIN} Qt${QT_VERSION_MAJOR}::Qml Qt${QT_VERSION_MAJOR}::Quick Qt${QT_VERSION_MAJOR}::DBus Qt${QT_VERSION_MAJOR}::Contacts)

# Where this QML module is installed. The top level project sets it: a click
# package and a system install do not use the same layout. The fallback keeps
# this directory configurable on its own.
if(NOT PLUGIN_IMPORT_DIR)
    execute_process(
        COMMAND dpkg-architecture -qDEB_HOST_MULTIARCH
        OUTPUT_VARIABLE ARCH_TRIPLET
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    set(PLUGIN_IMPORT_DIR "lib/${ARCH_TRIPLET}")
endif()

# Install the plugin to the specified Qt imports directory
install(TARGETS ${PLUGIN} DESTINATION ${PLUGIN_IMPORT_DIR}/${PLUGIN}/)
install(FILES qmldir DESTINATION ${PLUGIN_IMPORT_DIR}/${PLUGIN}/)
