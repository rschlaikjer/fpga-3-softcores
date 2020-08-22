cmake_policy(SET CMP0057 NEW)
function(synth_ice40 TARGET_NAME)

find_program(YOSYS_CMD yosys)
find_program(NEXTPNR_ICE40_CMD nextpnr-ice40)
find_program(ICEPACK_CMD icepack)
find_program(FPGA_PROG_CMD faff)

# Compose the yosys command
set(YOSYS_READ_VERILOG "")
foreach(source ${VERILOG_SOURCES})
    if(NOT IS_ABSOLUTE ${source})
        get_filename_component(source ${source} ABSOLUTE)
    endif()
    if (NOT ${source} IN_LIST QUALIFIED_VERILOG_SOURCES)
    list(APPEND QUALIFIED_VERILOG_SOURCES ${source})
    set(YOSYS_READ_VERILOG ${YOSYS_READ_VERILOG} " read_verilog ${source}")
    endif()
endforeach()
set(YOSYS_CMDLINE ${YOSYS_READ_VERILOG} " synth_ice40 -top ${PROJECT_TOP} -json ${PROJECT_NAME}.json ${SYNTHESIS_ARGS}")

# Nextpnr args
set(NEXTPNR_ARGS --${FPGA_DEVICE} --package ${FPGA_PACKAGE})
set(NEXTPNR_ARGS ${NEXTPNR_ARGS} --pcf ${PROJECT_SOURCE_DIR}/${PLACEMENT_FILE})
set(NEXTPNR_ARGS ${NEXTPNR_ARGS} --freq ${FREQ_MHZ})
set(NEXTPNR_ARGS ${NEXTPNR_ARGS} --json ${PROJECT_NAME}.json)
set(NEXTPNR_ARGS ${NEXTPNR_ARGS} --asc ${PROJECT_NAME}.asc)

# Packing
set(ICEPACK_ARGS ${PROJECT_NAME}.asc ${PROJECT_NAME}.bit)

# Synthesize
add_custom_command(
    OUTPUT ${PROJECT_NAME}.json
    COMMAND ${YOSYS_CMD} ARGS -p "${YOSYS_CMDLINE}"
    DEPENDS ${QUALIFIED_VERILOG_SOURCES}
    VERBATIM
)

# Place & route
add_custom_command(
    OUTPUT ${PROJECT_NAME}.asc
    COMMAND ${NEXTPNR_ICE40_CMD} ARGS ${NEXTPNR_ARGS}
    DEPENDS ${PROJECT_NAME}.json
    VERBATIM
)

# Pack bitstream
add_custom_command(
    OUTPUT ${PROJECT_NAME}.bit
    COMMAND ${ICEPACK_CMD} ARGS ${ICEPACK_ARGS}
    DEPENDS ${PROJECT_NAME}.asc
    VERBATIM
)

# Target to force synthesis
add_custom_target(${TARGET_NAME}_synth ALL
    DEPENDS ${PROJECT_NAME}.bit
)

# Programming
add_custom_target(${TARGET_NAME}_flash
    DEPENDS ${PROJECT_NAME}.bit
)
add_custom_command(
    TARGET ${TARGET_NAME}_flash
    COMMAND ${FPGA_PROG_CMD} ARGS -f ${PROJECT_NAME}.bit
    DEPENDS ${PROJECT_NAME}.bit
    VERBATIM
)

endfunction()
