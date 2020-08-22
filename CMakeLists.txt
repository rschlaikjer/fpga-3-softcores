cmake_minimum_required(VERSION 3.1.3)

project(ice40_soc C CXX)

# Load our extra FPGA function definitions
include(cmake/synthesis_ice40.cmake)
include(cmake/wishbone_intercon.cmake)
include(cmake/riscv.cmake)

# Set some paths
get_filename_component(VENDOR_DIR ${PROJECT_SOURCE_DIR}/vendor/ ABSOLUTE)
get_filename_component(PLACEMENTS_DIR ${PROJECT_SOURCE_DIR}/placements/ ABSOLUTE)
get_filename_component(SCRIPTS_DIR ${PROJECT_SOURCE_DIR}/scripts/ ABSOLUTE)

# Tests need to know where to find catch2
include_directories(${VENDOR_DIR}/catch/)

# Ensure verilator CMake support is present
find_package(verilator HINTS $ENV{VERILATOR_ROOT} ${VERILATOR_ROOT})
if (NOT verilator_FOUND)
    message(FATAL_ERROR "Could not find Verilator. Install or set $VERILATOR_ROOT")
endif()

# Integrate the catch tests with cmake's make test support
include(${VENDOR_DIR}/catch/ParseAndAddCatchTests.cmake)
enable_testing()

# Nextpnr args
set(NEXTPNR_ARGS --${FPGA_DEVICE} --package ${FPGA_PACKAGE})
set(NEXTPNR_ARGS ${NEXTPNR_ARGS} --pcf ${PROJECT_SOURCE_DIR}/${PLACEMENT_FILE})
set(NEXTPNR_ARGS ${NEXTPNR_ARGS} --freq ${FREQ_MHZ})
set(NEXTPNR_ARGS ${NEXTPNR_ARGS} --json ${PROJECT_NAME}.json)
set(NEXTPNR_ARGS ${NEXTPNR_ARGS} --asc ${PROJECT_NAME}.asc)


set(PROJECT_TOP top)
set(PLACEMENT_FILE hx4k_pmod.pcf)
set(FPGA_DEVICE hx8k)
set(FPGA_PACKAGE tq144:4k)
set(FREQ_MHZ 42)
set(SYNTHESIS_ARGS "-abc9 -dsp")
set(VERILOG_SOURCES
    rtl/top.v
    rtl/ice_pll.v
    rtl/fifo.v
    rtl/timer_wb.v
    rtl/rgb_led_wb.v
    rtl/uart_rx.v
    rtl/uart_tx.v
    rtl/uart_wb.v
    rtl/wb_ram.v
    # Generated sources
    rtl/gen/wb_intercon.v
    # Vendored sources
    ${VENDOR_DIR}/wb_intercon/rtl/verilog/wb_arbiter.v
    ${VENDOR_DIR}/wb_intercon/rtl/verilog/wb_mux.v
    ${VENDOR_DIR}/verilog-arbiter/src/arbiter.v
    ${VENDOR_DIR}/vexriscv/VexRiscv.v
)
# Create a synthesis target for the gateware
synth_ice40(${PROJECT_NAME})

# Create a wishbone generation target, and have it be a dependency of the
# synthesis target
wishbone_gen(
    PROJNAME ${PROJECT_NAME}
    CONFIG_FILE "${PROJECT_SOURCE_DIR}/wb_intercon.yaml"
    MODULE_NAME "wb_intercon"
    FOR_TARGET ${PROJECT_NAME}_synth
)

# Set up the firmware build
set(FIRMWARE_SOURCES
    firmware/start.s
    firmware/bootstrap.cpp
    firmware/main.cpp
)
set(FIRMWARE_LDSCRIPT
    firmware/sections.ld
)

# Create a firmware target, and have it also be a dependency of the synth target
compile_riscv(
    NAME ${PROJECT_NAME}_fw
    ARCH "rv32i"
    SOURCES ${FIRMWARE_SOURCES}
    LDSCRIPT ${FIRMWARE_LDSCRIPT}
    FOR_TARGET ${PROJECT_NAME}_synth
)

# Simulation target
add_executable(${PROJECT_NAME}_sim
    sim/main.cpp
)
verilate(${PROJECT_NAME}_sim COVERAGE TRACE
    INCLUDE_DIRS "${PROJECT_SOURCE_DIR}/rtl"
    VERILATOR_ARGS -O2 -x-assign 0 --top-module top
    SOURCES ${VERILOG_SOURCES}
)

# Sim depends on the firmware / wb gen
add_dependencies(${PROJECT_NAME}_sim
    ${PROJECT_NAME}_fw_build
    ${PROJECT_NAME}_wishbone_gen_wb_intercon
)

# Individual module tests
macro(define_test_target TEST_NAME)
add_executable(${PROJECT_NAME}_${TEST_NAME}_test
    test/test_main.cpp
    test/${TEST_NAME}_test.cpp)
verilate(${PROJECT_NAME}_${TEST_NAME}_test COVERAGE TRACE
    INCLUDE_DIRS "${PROJECT_SOURCE_DIR}/test"
    VERILATOR_ARGS -O2 -x-assign 0
    SOURCES ${PROJECT_SOURCE_DIR}/rtl/${TEST_NAME}.v
)
ParseAndAddCatchTests(${PROJECT_NAME}_${TEST_NAME}_test)
endmacro()
define_test_target(wb_ram)
define_test_target(fifo)
