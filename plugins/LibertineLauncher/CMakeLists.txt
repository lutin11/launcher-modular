set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(PLUGIN LibertineLauncher)

set(
    SRC
    plugin.cpp
    libertinelauncher.cpp
)

set(CMAKE_AUTOMOC ON)

add_library(${PLUGIN} MODULE ${SRC})
set_target_properties(${PLUGIN} PROPERTIES LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${PLUGIN})
qt5_use_modules(${PLUGIN} Qml Quick DBus)

# Link the necessary Qt5 modules
find_package(Qt5 REQUIRED COMPONENTS Core Qml Quick DBus)
target_link_libraries(${PLUGIN} Qt5::Core Qt5::Qml Qt5::Quick Qt5::DBus)

# Determine the architecture triplet for installation path
execute_process(
    COMMAND dpkg-architecture -qDEB_HOST_MULTIARCH
    OUTPUT_VARIABLE ARCH_TRIPLET
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

set(QT_IMPORTS_DIR "/lib/${ARCH_TRIPLET}")

install(TARGETS ${PLUGIN} DESTINATION ${QT_IMPORTS_DIR}/${PLUGIN}/)
install(FILES qmldir DESTINATION ${QT_IMPORTS_DIR}/${PLUGIN}/)
