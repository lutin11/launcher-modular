# Specify C++11 standard
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11")

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

# Get the architecture triplet for multi-arch support
execute_process(
    COMMAND dpkg-architecture -qDEB_HOST_MULTIARCH
    OUTPUT_VARIABLE ARCH_TRIPLET
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

# Define the Qt imports directory
set(QT_IMPORTS_DIR "/lib/${ARCH_TRIPLET}")

# Install the plugin to the specified Qt imports directory
install(TARGETS ${PLUGIN} DESTINATION ${QT_IMPORTS_DIR}/${PLUGIN}/)
install(FILES qmldir DESTINATION ${QT_IMPORTS_DIR}/${PLUGIN}/)
