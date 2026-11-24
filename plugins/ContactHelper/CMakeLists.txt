set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

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
find_package(Qt5 REQUIRED COMPONENTS Qml Quick DBus Contacts)

# Add the plugin as a module
add_library(${PLUGIN} MODULE ${SRC})

# Set library output directory
set_target_properties(${PLUGIN} PROPERTIES LIBRARY_OUTPUT_DIRECTORY ${PLUGIN})

# Link the necessary Qt modules to the plugin target
target_link_libraries(${PLUGIN} Qt5::Qml Qt5::Quick Qt5::DBus Qt5::Contacts)

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
