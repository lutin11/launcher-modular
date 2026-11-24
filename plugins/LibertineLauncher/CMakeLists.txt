set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(PLUGIN LibertineLauncher)

set(
    SRC
    plugin.cpp
    libertinelauncher.cpp
    libertineworker.cpp
)

set(CMAKE_AUTOMOC ON)

find_package(Qt5 REQUIRED COMPONENTS Core Qml Quick DBus)
add_library(${PLUGIN} MODULE ${SRC})
set_target_properties(${PLUGIN} PROPERTIES LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${PLUGIN})
target_link_libraries(${PLUGIN} Qt5::Core Qt5::Qml Qt5::Quick Qt5::DBus)

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
