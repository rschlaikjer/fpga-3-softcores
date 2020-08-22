/* Define our main memory regions - we created two memory blocks, one to act as
 * RAM and one to contain our program (ROM). The address here should match the
 * address we gave the memories in our wishbone memory layout.
 */
MEMORY {
    ram (rwx)   :   ORIGIN = 0x80000000, LENGTH = 0x00000800
    rom (rx)    :   ORIGIN = 0x20000000, LENGTH = 0x00001000
}

/* Now we need to locate our sections within those memories. */
SECTIONS {
    /* Firstly, our text section. This will contain the program code, and any
     * other read-only data. This data is immutable, and we will locate it
     * inside our ROM block
     */
    .text : {
        /* Ensure that our reset vector code is at the very beginning of ROM,
         * where our CPU will start execution
         */
        *(.reset_vector*)
        /* Program code */
        *(.text*)
        /* Ensure that the next block is aligned to a 32-bit word boundary */
        . = ALIGN(4);
        /* Read-only data */
        *(.rodata*)
        /* Ensure that the next block is aligned to a 32-bit word boundary */
    } >rom /* Locate this group inside the ROM memory */

    /* These next three groups are sections that contain a list of function
     * pointers, used by C++ code to perform static constructor/destructor calls
     * pre/post-main.
     * These are static memory regions, so we will locate them in ROM as well.
     */
    .preinit_array : {
        . = ALIGN(4);
        /* Export a symbol with the address of the start of the preinit array.
         * This symbol, and the corresponding one at the end of the array, will
         * be used by our startup code to locate and iterate these functions
         */
        __preinit_array_start = .;
        /* Insert the preinit array section, and force ld to KEEP it even if it
         * otherwise looks like it might be unused.
         */
        KEEP (*(.preinit_array))
        __preinit_array_end = .;
    } >rom
    .init_array : {
        . = ALIGN(4);
        __init_array_start = .;
        KEEP (*(SORT(.init_array.*)))
        KEEP (*(.init_array))
        __init_array_end = .;
    } >rom
    .fini_array : {
        . = ALIGN(4);
        __fini_array_start = .;
        KEEP (*(.fini_array))
        KEEP (*(SORT(.fini_array.*)))
        __fini_array_end = .;
    } >rom

    /* We have now reached the end of the read-only text segment. Export the
     * _etext symbol with this location in case it is needed.
     */
    . = ALIGN(4);
    _etext = .;

    /* Now that we are done with our read-only sections, we can move on to RAM.
     * There are two sections we care about here: .data, which is initialized
     * variable memory, and .bss, which is zero-initialized memory.
     */

    /* Our data segment is special in that it has both a location in rom (where
     * the data to be loaded into memory is stored) and in ram (where the data
     * must be copied to before main() is called).
     */
    .data : {
        /* Export a symbol for the start of the data section */
        _data = .;
        /* Insert our actual data */
        *(.data*)
        . = ALIGN(4);
        /* Insert the small data section at the end, so that it is close to the
         * small bss section at the start of the next segment
         */
        __global_pointer$ = . + 0x800;
        *(.sdata*)
        . = ALIGN(4);
        /* And also make a note of where the section ends */
        _edata = .;
    /* This section is special in having a Load Memory Address (LMA) that is
     * different from the Virtual Memory Address (VMA). When the program is
     * executing, it will expect the data in this section to be located at the
     * VMA (in this case, in RAM). But since we need this data to be
     * initialized, and RAM is volatile, it must have a different location for
     * the data to be loaded _from_, the LMA. In our case, the LMA is inside the
     * non-volatile ROM segment.
     */
    } >ram AT >rom /* VMA in ram, LMA in rom */

    /* Since we will need to reference the LMA of the .data section in our
     * startup code (so that we may copy the data into ram), we need the linker
     * to export a symbol here with that value.
     */
    _data_loadaddr = LOADADDR(.data);

    /* Finally, we get to our memory that doesn't require special
     * initialization
     */
    .bss : {
        /* Insert the small .sbss section first, so that it is close to
         * the small data section
         */
         *(.sbss*)
        . = ALIGN(4);
        /* Insert the .bss (zero-initialized) section */
         *(.bss*)
        /* Also include the COMMON (uninitialized) section */
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } >ram

    /* That's it for sections - for completeness, we also export a symbol at the
     * very end of our memory range.
     */
    . = ALIGN(4);
    end = .;
}

/* Finally, we need to tell our startup code where to locate the stack. Since
 * the stack grows down, we export the stack start symbol to be at the end of
 * our RAM memory section.
 */
PROVIDE(_stack = ORIGIN(ram) + LENGTH(ram));
