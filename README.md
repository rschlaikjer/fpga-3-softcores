# FPGA Soft CPU SoC Demonstration

This repo contains the files associated with
[this blog post](https://rhye.org/post/fpgas-3-softcores/),
which covers:

- Customizing and generating a VexRiscv CPU core
- Creating custom wishbone peripherals and attaching them to the CPU
- Linking and bringup of a bare-metal RISC-V firmware image
- Memory mapped IO
- RISC-V interrupt handling

![SoC with Interrupts + Peripheral Demo](/img/soc_blink.gif)

## Repo layout

This repo is broken out in the following main subfolders:

- cmake: Custom function definitions for generating wishbone interconnects,
  FPGA synthesis targets and RISC-V firmware targets
- firmware: Linker scripts, startup files and application code for the firmware
  that runs on the demo SoC
- rtl: All non-vendored Verilog code used to genreate the SoC. This includes
  all wishbone peripherals (Interrupt timer, RGB LED controller and buffered UART),
  the device-specific PLL and the top-level module.
- scripts: Small scripts used as part of the build process
- sim: Source code for simulating the entire design under verilator and
  generating a trace file.
- test: Test cases against individual Verilog modules. These tests are built
  using the [catch2](https://github.com/catchorg/Catch2)
  framework, and can be invoked using the `make test` target.
- vendor: Third party code necessary for building the SoC. Primarily,
    - Catch2, the testing framework
    - wb_intercon, a custom wishbone interconnect generator
    - verilog-arbiter, a dependency of wb_intercon
    - The generated VexRiscv core and associated SpinalHDL configuration

## Building

In order to fully build this repo, one must have all of
- cmake
- yosys / nextpnr
- verilator
- riscv-gcc

If deploying to the hardware target shown in the blog post and
[this repo](https://github.com/rschlaikjer/hx4k-pmod),
you will also need the
[faff](https://github.com/rschlaikjer/faff)
programming utility.

Steps are provided below to install each component on a Debian based system.

### Yosys

```
sudo apt install -y checkinstall build-essential clang bison flex \
    libreadline-dev gawk tcl-dev libffi-dev git \
    graphviz xdot pkg-config python3 libboost-system-dev \
    libboost-python-dev libboost-filesystem-dev zlib1g-dev

git clone https://github.com/YosysHQ/yosys.git
cd yosys
make config-gcc
make -j$(nproc)
checkinstall -D -y --pkgname yosys
yosys -V
```

### Icestorm

```
sudo apt install -y build-essential clang bison flex libreadline-dev \
        gawk tcl-dev libffi-dev git mercurial graphviz   \
        xdot pkg-config python python3 libftdi-dev \
        qt5-default python3-dev libboost-all-dev cmake
git clone https://github.com/cliffordwolf/icestorm.git
cd icestorm
make -j$(nproc)
checkinstall -D -y --pkgname icestorm
```

### Nextpnr

Note that this configuration only includes the icestorm target, not the ECP5
targets. Install project trellis and use `-DARCH=all` to enable ECP5 support.

```
sudo apt install -y clang-format qt5-default python3-dev libboost-dev \
        libboost-filesystem-dev libboost-thread-dev \
        libboost-program-options-dev libboost-python-dev \
        libboost-iostreams-dev libboost-dev libeigen3-dev

git clone https://github.com/YosysHQ/nextpnr.git
cd nextpnr
cmake -DARCH=ice40 .
make -j$(nproc)
checkinstall -D -y --pkgname nextpnr
```

### Verilator

```
sudo apt install -y git make autoconf g++ flex bison
git clone https://github.com/verilator/verilator.git -b v4.028
cd verilator
unset VERILATOR_ROOT
autoconf
./configure
make -j$(nproc)
checkinstall -D -y --pkgname verilator --pkgversion 4.028
```

### RISC-V GCC

```
sudo apt install -y autoconf automake autotools-dev curl python3 \
        libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex \
        texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev
git clone --recursive https://github.com/riscv/riscv-gnu-toolchain.git
cd riscv-gnu-toolchain
./configure --prefix=/opt/riscv32i/ --with-arch=rv32i
make -j$(nproc) && sudo make install
export PATH="/opt/riscv32i/bin:${PATH}" # Add to your .bashrc or equivalent
```

## Running simulations / tests

In order to simulate the entire design for a given number of cycles, build
and run the target `ice40_soc_sim`:

    cd fpga-3-softcores
    mkdir build
    cd build
    cmake ../
    make ice40_soc_sim && ./ice40_soc_sim

This will produce a file called `sim_out.vcd` in your build directory, which
can be opened with Gtkwave.

In order to build and run tests:

    # Build the test binaries
    make ice40_soc_wb_ram_test ice40_soc_fifo_test
    # Run tests
    make test

## Deploying to hardware

As written, this repo is designed to run on
[this dev board](https://github.com/rschlaikjer/hx4k-pmod),
but should be quite portable to other devices.
If running on the HX4K board, then running

    make && faff -f ice40_soc.bit

will build the bitstream and load it onto the board.

If porting to another platform, the placement file and chip specificiations may
be changed near the top of the master CMakeLists.txt
