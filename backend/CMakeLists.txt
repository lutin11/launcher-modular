include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}
)

add_definitions(
  -DGETTEXT_PACKAGE=\"${PROJECT_NAME}\"
  -DGETTEXT_LOCALEDIR=\"${CMAKE_INSTALL_LOCALEDIR}\"
)

set(
    helperFunctions_SRCS

    modules/HelperFunctions/backend.cpp
    modules/HelperFunctions/helperfunctions.cpp
)


add_library(helperfunctions MODULE
    ${helperFunctions_SRCS}
)

set_target_properties(helperfunctions PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY HelperFunctions
)

qt5_use_modules(helperfunctions Gui Qml Quick DBus)

# Copy qmldir file to build dir for running in QtCreator
add_custom_target(helperfunctions-qmldir ALL
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/modules/HelperFunctions/qmldir ${CMAKE_CURRENT_BINARY_DIR}/HelperFunctions
    DEPENDS ${QMLFILES}
)

# Install plugin file
install(TARGETS helperfunctions DESTINATION ${MODULE_PATH}/HelperFunctions/)
install(FILES   modules/HelperFunctions/qmldir DESTINATION ${MODULE_PATH}/HelperFunctions/)
