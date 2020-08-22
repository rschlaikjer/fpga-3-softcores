#pragma once

#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>

#include <stdlib.h>
#include <verilated.h>
#include <verilated_vcd_c.h>

#include <catch.hpp>

/*
 * This file contains some templated structures that make writing tests a bit
 * more convenient. These structures assume that all modules follow a naming
 * convention that has a primary clock called i_clk, and active-high reset
 * called i_reset.
 * The Wishbone version of the test class also assumes that the
 * interface matches a common naming pattern.
 */

template <typename T, typename std::enable_if<std::is_base_of<
                          VerilatedModule, T>::value>::type * = nullptr>
struct TestData {
  // Verilated module
  T *module;

  // Trace context
  VerilatedVcdC *trace;

  // Current time tick
  uint64_t time_ns = 0;

  // Evaluate the module and write a new trace entry
  void eval() {
    module->eval();
    trace->dump(time_ns++);
  }

  // Creates a new test data with a given trace output file
  TestData(const char *trace_name) {
    Verilated::traceEverOn(true);
    module = new T;
    trace = new VerilatedVcdC();
    module->trace(trace, 99);
    trace->open(trace_name);
  }

  ~TestData() {
    if (module != nullptr) {
      free(module);
    }
    if (trace != nullptr) {
      trace->flush();
      trace->close();
    }
  }

  // Clock the module for N half-clock cycles
  void idle_clock(int count) {
    while (count--) {
      module->i_clk = module->i_clk ? 0 : 1;
      eval();
    }
  }

  // Perform a reset of the module
  void reset() {
    module->i_clk = 0;
    module->i_reset = 1;
    eval();
    module->i_clk = 1;
    eval();
    module->i_clk = 0;
    module->i_reset = 0;
    eval();
  }
};

template <typename T> struct WishboneTestData : public TestData<T> {

  using TestData<T>::TestData;

  uint32_t wb_read(uint32_t address, int timeout = 32) {
    // Assert we were called at negedge
    REQUIRE(this->module->i_clk == 0);

    // Set up read
    this->module->i_wb_adr = address;
    this->module->i_wb_dat = 0x0;
    this->module->i_wb_sel = 0b1111;
    this->module->i_wb_we = 0;
    this->module->i_wb_cyc = 1;
    this->module->i_wb_stb = 1;

    // Latch read
    this->module->i_clk = 1;
    this->eval();

    // Clock until ack goes high
    while (!this->module->o_wb_ack && timeout--) {
      this->module->i_clk = this->module->i_clk ? 0 : 1;
      this->eval();
    }
    REQUIRE(this->module->o_wb_ack == 1);

    // Clear wb signals
    this->module->i_wb_adr = 0;
    this->module->i_wb_dat = 0;
    this->module->i_wb_sel = 0;
    this->module->i_wb_cyc = 0;
    this->module->i_wb_stb = 0;

    // Restore clock to low
    this->module->i_clk = 0;
    this->eval();

    // Return data
    return this->module->o_wb_dat;
  }

  void wb_write(uint32_t address, uint32_t data, uint8_t sel = 0b1111,
                int timeout = 32) {
    // Assert we were called at negedge
    REQUIRE(this->module->i_clk == 0);

    // Set up read
    this->module->i_wb_adr = address;
    this->module->i_wb_dat = data;
    this->module->i_wb_sel = sel;
    this->module->i_wb_we = 1;
    this->module->i_wb_cyc = 1;
    this->module->i_wb_stb = 1;

    // Latch read
    this->module->i_clk = 1;
    this->eval();

    // Clock until ack goes high
    while (!this->module->o_wb_ack && timeout--) {
      this->module->i_clk = this->module->i_clk ? 0 : 1;
      this->eval();
    }
    REQUIRE(this->module->o_wb_ack == 1);

    // Clear wb signals
    this->module->i_wb_adr = 0;
    this->module->i_wb_dat = 0;
    this->module->i_wb_sel = 0;
    this->module->i_wb_cyc = 0;
    this->module->i_wb_stb = 0;

    // Restore clock to low
    this->module->i_clk = 0;
    this->eval();
  }
};
