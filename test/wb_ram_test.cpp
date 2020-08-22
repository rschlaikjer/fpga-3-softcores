#include <catch.hpp>

#include "test_utils.hpp"

#include <Vwb_ram.h>

static const int RAM_SIZE_WORDS = 512;

TEST_CASE("Read/write with sel test", "[MEMORY]") {
  WishboneTestData<Vwb_ram> td("wb_ram_test.vcd");

  // Write some data to address zero
  td.wb_write(0x0, 0xDEADBEEF);

  // Assert that we may read it back
  REQUIRE(td.wb_read(0x0) == 0xDEADBEEF);

  // Write something else to the next 32-bit word address
  td.wb_write(0x4, 0xFA73C0DE);
  REQUIRE(td.wb_read(0x4) == 0xFA73C0DE);

  // The second write should not have affected our first write
  REQUIRE(td.wb_read(0x0) == 0xDEADBEEF);

  // Write a new word, but only select the lower two bytes
  td.wb_write(0x0, 0xFEEDCAFE, 0b0011);

  // Assert that when we read the data back, only the low bytes changed
  REQUIRE(td.wb_read(0x0) == 0xDEADCAFE);

  // Check the same is true for the high bytes
  td.wb_write(0x0, 0xFACEF00D, 0b1100);
  REQUIRE(td.wb_read(0x0) == 0xFACECAFE);
}
