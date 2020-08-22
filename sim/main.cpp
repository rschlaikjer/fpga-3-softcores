#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>

#include <stdlib.h>
#include <verilated.h>
#include <verilated_vcd_c.h>

#include <Vtop.h>

int main() {
  Verilated::traceEverOn(true);
  Vtop *top = new Vtop;
  VerilatedVcdC *trace = new VerilatedVcdC();
  top->trace(trace, 99);
  trace->open("sim_out.vcd");

  const float wb_clk_hz = 12'000'000;
  const float nanoseconds_per_wb_clk = 1'000'000'000 / wb_clk_hz;
  float ns_since_last_wb_clk_tick = 0;

  for (int i = 0; i < 8'000'000; i++) {
    // Update the clock
    if (ns_since_last_wb_clk_tick++ > nanoseconds_per_wb_clk / 2) {
      top->CLK_12MHZ = top->CLK_12MHZ ? 0 : 1;
      ns_since_last_wb_clk_tick -= nanoseconds_per_wb_clk;
    }

    top->eval();
    trace->dump(i);
  }

  return 0;
}
