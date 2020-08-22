cmake_policy(SET CMP0057 NEW)

function(compile_riscv)

cmake_parse_arguments(
    CONF
    ""
    "NAME;ARCH;LDSCRIPT;FOR_TARGET"
    "SOURCES;CFLAGS"
    ${ARGN}
)

# Locate the riscv toolchain components
set(RISCV_PREFIX riscv32-unknown-elf)
find_program(RISCV_CXX ${RISCV_PREFIX}-g++)
find_program(RISCV_OBJCOPY ${RISCV_PREFIX}-objcopy)

# Find the bin -> reversed hex tool
find_program(MAKEHEX_PY makehex.py ${SCRIPTS_DIR})

# Resolve paths relative to the source dirs
get_filename_component(CONF_LDSCRIPT ${CONF_LDSCRIPT} ABSOLUTE)

set(SOURCES_STR "")
foreach(source ${CONF_SOURCES})
    if(NOT IS_ABSOLUTE ${source})
        get_filename_component(source ${source} ABSOLUTE)
    endif()
    if (NOT ${source} IN_LIST QUALIFIED_SOURCES)
        list(APPEND QUALIFIED_SOURTCES ${source})
        set(SOURCES_STR ${SOURCES_STR} ${source})
    endif()
endforeach()

# Compile command for the elf itself
set(ELF_FILE ${CONF_NAME}_elf)
set(CFLAGS -g -march=${CONF_ARCH} --static -nostartfiles -ffreestanding ${CONF_CFLAGS})
set(LDFLAGS -Wl,-Bstatic,-T,${CONF_LDSCRIPT},-Map,${CONF_NAME}.map)
add_custom_command(
    OUTPUT ${ELF_FILE}
    COMMAND ${RISCV_CXX} ARGS ${CFLAGS} ${LDFLAGS} -o ${ELF_FILE} ${SOURCES_STR}
    DEPENDS ${SOURCES_STR}
)

# Generate a raw binary file from the elf
set(BIN_FILE ${CONF_NAME}_bin)
add_custom_command(
    OUTPUT ${BIN_FILE}
    DEPENDS ${ELF_FILE}
    COMMAND ${RISCV_OBJCOPY} ARGS -O binary ${ELF_FILE} ${BIN_FILE}
)

# Generate an endian-swapped hex file, for loading with $readmemh
set(HEX_FILE ${CONF_NAME}_hex)
add_custom_command(
    OUTPUT ${HEX_FILE}
    DEPENDS ${BIN_FILE}
    COMMAND ${MAKEHEX_PY} ARGS ${BIN_FILE} > ${HEX_FILE}
)

add_custom_target(${CONF_NAME}_build
    DEPENDS ${HEX_FILE}
)

add_dependencies(${CONF_FOR_TARGET} ${CONF_NAME}_build)

endfunction()
