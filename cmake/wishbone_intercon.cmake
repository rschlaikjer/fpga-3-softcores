function(wishbone_gen)

cmake_parse_arguments(
    CONF
    ""
    "CONFIG_FILE;MODULE_NAME;FOR_TARGET;PROJNAME"
    ""
    ${ARGN}
)

find_program(GEN_CMD wb_intercon_gen2.py ${VENDOR_DIR}/wb_intercon/sw)

set(CMDLINE ${CONF_CONFIG_FILE} "${CONF_MODULE_NAME}.v" "${CONF_MODULE_NAME}")

add_custom_command(
    OUTPUT ${CONF_MODULE_NAME}
    COMMAND ${GEN_CMD} ARGS ${CMDLINE}
    DEPENDS ${CONF_CONFIG_FILE}
    WORKING_DIRECTORY  ${PROJECT_SOURCE_DIR}/rtl/gen
    VERBATIM
)

add_custom_target(${CONF_PROJNAME}_wishbone_gen_${CONF_MODULE_NAME}
    DEPENDS ${CONF_MODULE_NAME}
)

add_dependencies(${CONF_FOR_TARGET} ${CONF_PROJNAME}_wishbone_gen_${CONF_MODULE_NAME})

endfunction()
