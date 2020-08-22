# Since we need to ensure that this is the very first code the CPU runs at
# startup, we place it in a special reset vector section that we link before
# anything else in the .text region
.section .reset_vector

# In order to initialize the stack pointer, we need to know where in memory
# the stack begins. Our linker script will provide this symbol.
.global _stack

# Our main application entrypoint label
start:

# Initialize global pointer
# Need to set norelax here, otherwise the optimizer might convert this to
# mv gp, gp which wouldn't be very useful
.option push
.option norelax
la gp, __global_pointer$
.option pop

# Load the address of the _stack label into the stack pointer
la sp, _stack

# Once the register file is initialized and the stack pointer is set, we can
# jump to our actual program entry point
call reset_handler

# If our reset handler ever returns, just keep the CPU in an infinite loop.
loop:
j loop
