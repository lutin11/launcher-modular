set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# The top-level build sets this; keep a standalone configure working on Qt 5.
if(NOT DEFINED QT_VERSION_MAJOR)
    set(QT_VERSION_MAJOR 5)
endif()
set(PLUGIN "Terminalaccess")

set(
    SRC
    plugin.cpp
    terminalaccess.cpp
)

set(CMAKE_AUTOMOC ON)

find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Core Qml Quick DBus)
add_library(${PLUGIN} MODULE ${SRC})
set_target_properties(${PLUGIN} PROPERTIES LIBRARY_OUTPUT_DIRECTORY ${PLUGIN})
target_link_libraries(${PLUGIN} Qt${QT_VERSION_MAJOR}::Core Qt${QT_VERSION_MAJOR}::Qml Qt${QT_VERSION_MAJOR}::Quick Qt${QT_VERSION_MAJOR}::DBus)

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

install(TARGETS ${PLUGIN} DESTINATION ${PLUGIN_IMPORT_DIR}/${PLUGIN}/)
install(FILES qmldir DESTINATION ${PLUGIN_IMPORT_DIR}/${PLUGIN}/)
