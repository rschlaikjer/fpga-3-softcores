#include <stdint.h>

extern "C" {
int main(void);
void init(void);
void loop(void);
void blocking_handler(void);
void timer_interrupt(void);
}

#define CPU_CLK_HZ 42'000'000

#define MMIO32(ADDR) (*(volatile uint32_t *)(ADDR))
#define REG32(BASE, OFFSET) MMIO32(BASE + (OFFSET << 2))

// Timer for driving the machine timer interrupt
// Note that since each register is 32 bits wide, subsequent register addresses
// are 4 bytes apart
#define TIMER_BASE 0x40000000
#define TIMER_PRESCALER REG32(TIMER_BASE, 0x00)
#define TIMER_FLAGS REG32(TIMER_BASE, 0x01)
#define TIMER_FLAGS__PENDING (1 << 0)

// Buffered UART
#define UART_BASE 0x40001000
// Baudrate prescaler counter
#define UART_PRESCALER REG32(UART_BASE, 0x00)
// Transmit block
#define UART_TX_FLAGS REG32(UART_BASE, 0x10)
#define UART_TX_BUFFER_COUNT REG32(UART_BASE, 0x11)
#define UART_TX_BUFFER_FREE REG32(UART_BASE, 0x12)
#define UART_TX_BUFFER_WRITE REG32(UART_BASE, 0x13)
// Receive block
#define UART_RX_FLAGS REG32(UART_BASE, 0x20)
#define UART_RX_BUFFER_COUNT REG32(UART_BASE, 0x21)
#define UART_RX_BUFFER_FREE REG32(UART_BASE, 0x22)
#define UART_RX_BUFFER_READ REG32(UART_BASE, 0x23)

// RGB LED
#define LED_BASE 0x40002000
#define LED_PWM_PRESCALER REG32(LED_BASE, 0)
#define LED_BGR_DATA REG32(LED_BASE, 1)

// Application code entrypoint
int main(void) {
  init();
  while (true) {
    loop();
  }
}

// Since we don't necessarily want to define all of these interrupt handlers up
// front, we will start by defining a simple blocking handler and pointing all
// interrupts there.
void blocking_handler(void) {
  while (1) {
  }
}

// Let's also create a simple timer interrupt handler
volatile uint32_t time_ms = 0;
void timer_interrupt(void) {
  // Increment the millisecond counter
  time_ms++;

  // We need to also clear the source of the interrupt, otherwise when we
  // return from interrupt it will just fire again right away.
  TIMER_FLAGS |= TIMER_FLAGS__PENDING;
}

// Create a type alias for our exception handlers, which are void functions
typedef void (*isr_vector)(void);

// The basic interrupts for RISC-V are the software, timer and external
// interrupts, each of which is specified for the user, supervisor and machine
// privilege levels. For clear naming, we will create a struct that matches the
// order of the interrupt codes.
struct {
  // Software interrupt
  isr_vector software_user_isr = &blocking_handler;
  isr_vector software_supervisor_isr = &blocking_handler;
  isr_vector software__reserved = &blocking_handler;
  isr_vector software_machine_isr = &blocking_handler;
  // Timer interrupt
  isr_vector timer_user_isr = &blocking_handler;
  isr_vector timer_supervisor_isr = &blocking_handler;
  isr_vector timer__reserved = &blocking_handler;
  isr_vector timer_machine_isr = &timer_interrupt;
  // External interrupt
  isr_vector external_user_isr = &blocking_handler;
  isr_vector external_supervisor_isr = &blocking_handler;
  isr_vector external__reserved = &blocking_handler;
  isr_vector external_machine_isr = &blocking_handler;
} vector_table;

// We need to decorate this function with __attribute__((interrupt)) so that
// the compiler knows to save/restore all register state, as well as to
// re-enable interrupts on return with the mret instruction.
void __attribute__((interrupt)) interrupt_handler(void) {
  // When an interrupt occurs, the mcause register contains the interrupt type
  uint32_t mcause;
  asm volatile("csrr %0, mcause" : "=r"(mcause));

  // The top bit of mcause is the sync vs async exception bit, we don't
  // handle that here so mask it off
  mcause &= 0x7FFFFFFF;

  // If the cause is some number out of range of our handler table, we have
  // no way to handle this interrupt! Block forever.
  if (mcause >= (sizeof(vector_table) / sizeof(isr_vector))) {
    while (true) {
    }
  }

  // Otherwise, we can jump to the handler listed in our vector table.
  // Since we took care to order our struct to match the interrupt IDs, we can
  // reinterpret it as an array for easy indexing based on mcause
  ((isr_vector *)&vector_table)[mcause]();
}

void init() {
  // Write that address into our mtvec register.
  // Since our address is 32-bit aligned, we are in non-vectored mode by default
  asm volatile("csrw mtvec, %0" ::"r"(&interrupt_handler));

  // We now want to enable the machine timer interrupt. To do this, we need to
  // set bit 7 in the Machine Interrupt Enable (mie) register
  asm volatile("csrs mie, %0" ::"r"(1 << 7));

  // We then need to enable machine interrupts globally, by setting bit 3 in the
  // Machine Status Register (mstatus).
  asm volatile("csrs mstatus, %0" ::"i"(1 << 3));

  // Set our uart prescaler
  UART_PRESCALER = CPU_CLK_HZ / 2'000'000 - 1;

  // Set our timer counter prescaler
  TIMER_PRESCALER = CPU_CLK_HZ / 1'000 - 1;

  // 1kHz LED PWM with 256 counter states
  LED_PWM_PRESCALER = CPU_CLK_HZ / 256 / 1'000 - 1;
}

// Extremely basic integer formatting method
// Uses a static internal buffer, so subsequent calls will invalidate the data
const char *unsigned_to_str(uint32_t val) {
  static char out_buf[11];
  // Max size of u32 is 4294967295, or 10 characters.
  // Plus one for null byte.
  int out_buf_idx = 11;
  out_buf[--out_buf_idx] = '\0';
  while (val) {
    const unsigned digit = val % 10;
    val = val / 10;
    out_buf[--out_buf_idx] = '0' + digit;
  }
  return &out_buf[out_buf_idx];
}

// Writes a string out to the uart.
// Does not check that the uart buffer has enough space, so sending too much
// data without either
// - Checking the uart flags register for a fill condition or
// - Altering the uart gateware to delay ACKs on writes until the buffer can
//   accomodate
// will result in lost byes.
void uart_write(const char *str) {
  while (*str) {
    UART_TX_BUFFER_WRITE = *str;
    str++;
  }
}

// Main application event loop.
void loop() {
  // Check if it is time to print a log update
  static uint32_t last_uart_log = 0;
  if (time_ms - last_uart_log > 500) {
    // Update the last log timestamp
    last_uart_log = time_ms;

    // For fun, let's count how many CPU cycles it takes
    uint32_t cycle_start, cycle_end;
    // Read the current cycle counter
    asm volatile("rdcycle %0" : "=r"(cycle_start));

    // Format the current time into a buffer
    const char *time_str = unsigned_to_str(time_ms);
    // Write out a status string to the uart
    uart_write("The current time is ");
    uart_write(time_str);
    uart_write("\r\n");

    // Read the cycle counter again
    asm volatile("rdcycle %0" : "=r"(cycle_end));

    // Print how long the first print took, in cycles
    const char *cycle_str = unsigned_to_str(cycle_end - cycle_start);
    // Write out a status string to the uart
    uart_write("Previous log took ");
    uart_write(cycle_str);
    uart_write(" cycles to execute\r\n");
  }

  // Check if it's time to cycle our indicator LED
  static uint32_t last_led_update = 0;
  if (time_ms - last_led_update > 2) {
    // Update timer
    last_led_update = time_ms;

    // LED state
    static uint32_t led_data[3] = {0, 0, 0};
    static int led_count_up = 1;
    static uint32_t led_index = 0;

    // Cycle each LED on and off in intensity, one after the other
    if (led_count_up) {
      led_data[led_index]++;
      if (led_data[led_index] >= 255) {
        led_data[led_index] = 255;
        led_count_up = 0;
      }
    } else {
      led_data[led_index]--;
      if (led_data[led_index] == 0) {
        led_count_up = 1;
        led_index = (led_index + 1) % 3;
      }
    }

    // Pack the LED data and update our PWM peripheral
    LED_BGR_DATA = ((led_data[0] & 0xFF) | ((led_data[1] & 0xFF) << 8) |
                    ((led_data[2] & 0xFF) << 16));
  }
}

