extern unsigned _data_loadaddr, _data, _edata;

typedef void (*void_fun)(void);
extern void_fun __preinit_array_start, __preinit_array_end;
extern void_fun __init_array_start, __init_array_end;
extern void_fun __fini_array_start, __fini_array_end;

extern "C" {
int main(void);
void reset_handler(void);
}

void reset_handler(void) {
  // Load the initialized .data section into place
  volatile unsigned *src, *dest;
  for (src = &_data_loadaddr, dest = &_data; dest < &_edata; src++, dest++) {
    *dest = *src;
  }

  // Handle C++ constructors / anything with __attribute__(constructor)
  void_fun *fp;
  for (fp = &__preinit_array_start; fp < &__preinit_array_end; fp++) {
    (*fp)();
  }
  for (fp = &__init_array_start; fp < &__init_array_end; fp++) {
    (*fp)();
  }

  // Invoke our actual application
  main();

  // Run destructors
  for (fp = &__fini_array_start; fp < &__fini_array_end; fp++) {
    (*fp)();
  }
}
