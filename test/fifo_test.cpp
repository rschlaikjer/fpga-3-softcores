#include <catch.hpp>

#include <Vfifo.h>

#include "test_utils.hpp"

// Value of MAX_ENTRIES parameter minus one
static const int FIFO_MAX_ITEM_COUNT = 7;

TEST_CASE("FIFO R+W (not-full case)", "[FIFO]") {
  TestData<Vfifo> td("fifo_rw_not_full.vcd");
  td.reset();

  // FIFO should begin life empty
  REQUIRE(td.module->o_empty == 1);
  REQUIRE(td.module->o_full == 0);
  REQUIRE(td.module->o_item_count == 0);
  REQUIRE(td.module->o_free_size == FIFO_MAX_ITEM_COUNT);

  // Write a few data to the fifo
  uint16_t write_data[3] = {0xC0DE, 0xDEAD, 0xBEEF};
  for (int i = 0; i < sizeof(write_data) / sizeof(uint16_t); i++) {
    // Write the item to the fifo
    td.module->i_clk = 1;
    td.module->i_w_data = write_data[i];
    td.module->i_w_data_stb = 1;
    td.eval();

    // If this was the first datum, the output data on the read interface should
    // now be valid
    if (i == 0) {
      REQUIRE(td.module->o_r_data == write_data[0]);
    }

    // Assert that the fifo values update
    REQUIRE(td.module->o_empty == 0);
    REQUIRE(td.module->o_full == 0);
    REQUIRE(td.module->o_item_count == i + 1);
    REQUIRE(td.module->o_free_size == FIFO_MAX_ITEM_COUNT - (i + 1));
    td.module->i_clk = 0;
    td.eval();
  }

  // Current output on the read interface should be the first data we wrote
  REQUIRE(td.module->o_r_data == write_data[0]);

  // Perform a read+write on the same cycle
  td.module->i_clk = 1;
  td.module->i_w_data = 0xFEED;
  td.module->i_w_data_stb = 1;
  td.module->i_r_data_stb = 1;
  td.eval();

  // Size should still be 3
  REQUIRE(td.module->o_empty == 0);
  REQUIRE(td.module->o_full == 0);
  REQUIRE(td.module->o_item_count == 3);
  REQUIRE(td.module->o_free_size == FIFO_MAX_ITEM_COUNT - 3);

  // There is a one cycle delay on the read, so the next posedge should have the
  // new data on the read interface
  td.module->i_clk = 0;
  td.module->i_w_data_stb = 0;
  td.module->i_r_data_stb = 0;
  td.eval();
  td.module->i_clk = 1;
  td.eval();
  REQUIRE(td.module->o_r_data == write_data[1]);
}

TEST_CASE("FIFO R+W (full case)", "[FIFO]") {
  TestData<Vfifo> td("fifo_rw_full.vcd");
  td.reset();

  // FIFO should begin life empty
  REQUIRE(td.module->o_empty == 1);
  REQUIRE(td.module->o_full == 0);
  REQUIRE(td.module->o_item_count == 0);
  REQUIRE(td.module->o_free_size == FIFO_MAX_ITEM_COUNT);

  // Write until FIFO full
  uint16_t w_data[FIFO_MAX_ITEM_COUNT];
  int i = 0;
  while (!td.module->o_full) {
    // Write a random 16-bit word to the fifo
    td.module->i_clk = 1;
    td.module->i_w_data = rand() & 0xFFFF;
    w_data[i] = td.module->i_w_data;
    CAPTURE(td.module->i_w_data);
    td.module->i_w_data_stb = 1;
    td.eval();

    // Assert the size has increased
    i++;
    REQUIRE(td.module->o_empty == 0);
    REQUIRE(td.module->o_item_count == i);
    REQUIRE(td.module->o_free_size == FIFO_MAX_ITEM_COUNT - i);
    td.module->i_clk = 0;
    td.eval();
  }

  // The FIFO should now be totally full
  REQUIRE(td.module->o_empty == 0);
  REQUIRE(td.module->o_full == 1);
  REQUIRE(td.module->o_item_count == FIFO_MAX_ITEM_COUNT);
  REQUIRE(td.module->o_free_size == 0);

  // Perform a read and write on the same cycle
  td.module->i_clk = 1;
  td.module->i_w_data = rand() & 0xFFFF;
  td.module->i_w_data_stb = 1;
  td.module->i_r_data_stb = 1;
  td.eval();

  // The fifo should still be full
  REQUIRE(td.module->o_empty == 0);
  REQUIRE(td.module->o_full == 1);
  REQUIRE(td.module->o_item_count == FIFO_MAX_ITEM_COUNT);
  REQUIRE(td.module->o_free_size == 0);

  // Output data should be 0th written item until the next posedge
  REQUIRE(td.module->o_r_data == w_data[0]);
  td.module->i_clk = 0;
  td.eval();
  td.module->i_clk = 1;
  td.eval();
  REQUIRE(td.module->o_r_data == w_data[1]);
}

TEST_CASE("FIFO R (empty)", "[FIFO]") {
  TestData<Vfifo> td("fifo_r_empty.vcd");
  td.reset();

  // Assert empty
  REQUIRE(td.module->o_empty == 1);
  REQUIRE(td.module->o_full == 0);
  REQUIRE(td.module->o_item_count == 0);
  REQUIRE(td.module->o_free_size == FIFO_MAX_ITEM_COUNT);

  // Try and read
  td.module->i_clk = 1;
  td.module->i_r_data_stb = 1;
  td.eval();

  // Should still be empty
  REQUIRE(td.module->o_empty == 1);
  REQUIRE(td.module->o_full == 0);
  REQUIRE(td.module->o_item_count == 0);
  REQUIRE(td.module->o_free_size == FIFO_MAX_ITEM_COUNT);
}

TEST_CASE("FIFO R (full)", "[FIFO]") {
  TestData<Vfifo> td("fifo_r_full.vcd");
  td.reset();

  // Assert empty
  REQUIRE(td.module->o_empty == 1);
  REQUIRE(td.module->o_full == 0);
  REQUIRE(td.module->o_item_count == 0);
  REQUIRE(td.module->o_free_size == FIFO_MAX_ITEM_COUNT);

  // Write until FIFO full
  uint16_t w_data[FIFO_MAX_ITEM_COUNT];
  int i = 0;
  while (!td.module->o_full) {
    // Write a random 16-bit word to the fifo
    td.module->i_clk = 1;
    td.module->i_w_data = rand() & 0xFFFF;
    w_data[i] = td.module->i_w_data;
    CAPTURE(td.module->i_w_data);
    td.module->i_w_data_stb = 1;
    td.eval();

    // Assert the size has increased
    i++;
    REQUIRE(td.module->o_empty == 0);
    REQUIRE(td.module->o_item_count == i);
    REQUIRE(td.module->o_free_size == FIFO_MAX_ITEM_COUNT - i);
    td.module->i_clk = 0;
    td.eval();
  }

  // Assert full
  REQUIRE(td.module->o_empty == 0);
  REQUIRE(td.module->o_full == 1);
  REQUIRE(td.module->o_item_count == FIFO_MAX_ITEM_COUNT);
  REQUIRE(td.module->o_free_size == 0);

  // Read something
  td.module->i_clk = 1;
  td.module->i_w_data_stb = 0;
  td.module->i_r_data_stb = 1;
  td.eval();

  // Should no longer be full
  REQUIRE(td.module->o_empty == 0);
  REQUIRE(td.module->o_full == 0);
  REQUIRE(td.module->o_item_count == FIFO_MAX_ITEM_COUNT - 1);
  REQUIRE(td.module->o_free_size == 1);

  // Output data should be 0th written item until the next posedge
  REQUIRE(td.module->o_r_data == w_data[0]);
  td.module->i_clk = 0;
  td.eval();
  td.module->i_clk = 1;
  td.eval();
  REQUIRE(td.module->o_r_data == w_data[1]);
}

TEST_CASE("FIFO W (full)", "[FIFO]") {
  TestData<Vfifo> td("fifo_w_full.vcd");
  td.reset();

  // Assert empty
  REQUIRE(td.module->o_empty == 1);
  REQUIRE(td.module->o_full == 0);
  REQUIRE(td.module->o_item_count == 0);
  REQUIRE(td.module->o_free_size == FIFO_MAX_ITEM_COUNT);

  // Write until FIFO full
  uint16_t w_data[FIFO_MAX_ITEM_COUNT];
  int i = 0;
  while (!td.module->o_full) {
    // Write a random 16-bit word to the fifo
    td.module->i_clk = 1;
    td.module->i_w_data = rand() & 0xFFFF;
    w_data[i] = td.module->i_w_data;
    CAPTURE(td.module->i_w_data);
    td.module->i_w_data_stb = 1;
    td.eval();

    // Assert the size has increased
    i++;
    REQUIRE(td.module->o_empty == 0);
    REQUIRE(td.module->o_item_count == i);
    REQUIRE(td.module->o_free_size == FIFO_MAX_ITEM_COUNT - i);
    td.module->i_clk = 0;
    td.eval();
  }

  // Assert full
  REQUIRE(td.module->o_empty == 0);
  REQUIRE(td.module->o_full == 1);
  REQUIRE(td.module->o_item_count == FIFO_MAX_ITEM_COUNT);
  REQUIRE(td.module->o_free_size == 0);

  // Write again
  td.module->i_clk = 1;
  td.module->i_w_data = rand() & 0xFFFF;
  td.module->i_w_data_stb = 1;
  td.eval();

  // Assert still full
  REQUIRE(td.module->o_empty == 0);
  REQUIRE(td.module->o_full == 1);
  REQUIRE(td.module->o_item_count == FIFO_MAX_ITEM_COUNT);
  REQUIRE(td.module->o_free_size == 0);
}
