ENTRY(start)
_Min_Heap_Size = 0x100;      /* required amount of heap  */
_Min_Stack_Size = 0x100; /* required amount of stack */
OUTPUT_FORMAT("elf32-littleriscv","elf32-littleriscv","elf32-littleriscv")
OUTPUT_ARCH(riscv)

MEMORY {
	flash(rx) : ORIGIN = 0x10000000, LENGTH = 0x00001000
    ram(rwx)   : ORIGIN = 0x20000000, LENGTH = 0x00001000
}

_estack = ORIGIN(ram) + LENGTH(ram);    /* end of RAM */


SECTIONS {
    .text : {
        . = ALIGN(4);
        *(.text .text*);
        . = ALIGN(4);
        _srodata = .;
        /* _erodata = .; */
    } >flash

    /* .rodata : {
        . = ALIGN(4);
        *(.srodata .srodata* .rodata .rodata*)
        . = ALIGN(4);
    } > flash */

    .data : {
        . = ALIGN(4);
        _sdata = .;
        *(.data .data.*);
        *(.sdata .sdata.*);
        . = ALIGN(4);
        _edata = .;
    } >ram AT>flash

    .bss : {
        . = ALIGN(4);
        _sbss = .;
        *(.bss .bss.*);
        . = ALIGN(4);
        _ebss = .;
    } >ram

    ._user_heap_stack : {
        . = ALIGN(8);
        PROVIDE ( end = . );
        PROVIDE ( _end = . );
        . = . + _Min_Heap_Size;
        . = . + _Min_Stack_Size;
        . = ALIGN(8);
    } >ram
}