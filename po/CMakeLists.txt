find_program(GETTEXT_XGETTEXT_EXECUTABLE xgettext)
find_program(GETTEXT_MSGMERGE_EXECUTABLE msgmerge)
find_program(GETTEXT_MSGFMT_EXECUTABLE msgfmt)

set(DOMAIN ${FULL_PROJECT_NAME})
set(POT_FILE ${DOMAIN}.pot)
file(GLOB PO_FILES *.po)

message(STATUS "DEBUG: DESKTOP_FILE_NAME='${DESKTOP_FILE_NAME}' PROJECT_NAME='${PROJECT_NAME}' CMAKE_SOURCE_DIR='${CMAKE_SOURCE_DIR}'")

# Creates the .pot file containing the translations template
add_custom_target(generate_pot ALL
    COMMENT "Generating translation template"
    COMMAND ${INTLTOOL_EXTRACT} --update --type=gettext/ini
        --srcdir=${CMAKE_SOURCE_DIR} ${DESKTOP_FILE_NAME}.in

    COMMAND ${GETTEXT_XGETTEXT_EXECUTABLE} -o ${POT_FILE}
        -D ${CMAKE_SOURCE_DIR}
        -D ${CMAKE_CURRENT_BINARY_DIR}
        --from-code=UTF-8
        --c++ --qt --language=javascript --add-comments=TRANSLATORS
        --keyword=tr --keyword=tr:1,2 --keyword=N_ --keyword=_
        --package-name='${DOMAIN}'
        ${I18N_SRC_FILES}
    COMMAND ${CMAKE_COMMAND} -E copy ${POT_FILE} ${CMAKE_CURRENT_SOURCE_DIR})

# Refresh all .po files based on the updated .pot file
add_custom_target(update_po_files ALL
    COMMENT "Updating .po files based on the new .pot file"
    DEPENDS generate_pot
    COMMAND ${CMAKE_COMMAND} -E echo "Merging ${POT_FILE} with existing .po files..."
)

foreach(PO_FILE ${PO_FILES})
    add_custom_command(TARGET update_po_files POST_BUILD
        COMMAND ${GETTEXT_MSGMERGE_EXECUTABLE} --update --backup=none
            ${PO_FILE} ${POT_FILE}
        COMMENT "Updating ${PO_FILE}"
    )
endforeach()

# Builds the binary translations catalog for each language
# it finds source translations (*.po) for
foreach(PO_FILE ${PO_FILES})
    get_filename_component(LANG ${PO_FILE} NAME_WE)

    set(GMO_FILE ${CMAKE_CURRENT_BINARY_DIR}/${LANG}.gmo)
    add_custom_command(OUTPUT ${GMO_FILE}
        COMMAND ${GETTEXT_MSGFMT_EXECUTABLE} --output-file=${GMO_FILE} ${PO_FILE}
        DEPENDS ${PO_FILE}
        COMMENT "Compiling ${PO_FILE} to ${GMO_FILE}"
    )
    add_custom_target(mo_${LANG} ALL DEPENDS ${GMO_FILE})

    set(INSTALL_DIR /share/locale/${LANG}/LC_MESSAGES)
    install(FILES ${GMO_FILE}
            DESTINATION ${INSTALL_DIR}
            RENAME ${DOMAIN}.mo)
endforeach()