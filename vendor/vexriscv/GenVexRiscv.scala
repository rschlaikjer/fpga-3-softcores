package vexriscv.demo

import spinal.core._
import spinal.lib._
import spinal.lib.eda.altera.{InterruptReceiverTag, QSysify, ResetEmitterTag}
import vexriscv.ip.{DataCacheConfig, InstructionCacheConfig}
import vexriscv.plugin._
import vexriscv.{VexRiscv, VexRiscvConfig, plugin}

object GenVexRiscv{
  def main(args: Array[String]) {
    val report = SpinalVerilog{

      // CPU configuration
      val cpuConfig = VexRiscvConfig(
        plugins = List(

          // We need an instruction data bus on the CPU. This bus is separate
          // from the data bus for performance reasons, and here we will
          // instantiate the cached version of this plugin, which is a
          // significant performance improvement on a non-cached implementation
          new IBusCachedPlugin(
            // We want to be able to set the reset address in verilog later, so
            // leave it null here
            resetVector = null,
            // Conditional branches are speculatively executed.
            // There is no tracking of whether a branch is more likely to be
            // executed or not
            prediction = STATIC,
            // Include a 4KiB instruction cache
            config = InstructionCacheConfig(
              cacheSize = 4096,
              bytePerLine = 32,
              wayCount = 1,
              addressWidth = 32,
              cpuDataWidth = 32,
              memDataWidth = 32,
              catchIllegalAccess = true,
              catchAccessFault = true,
              asyncTagMemory = false,
              twoCycleRam = true
            )
          ),

          // Data bus. We don't add a cache here so that we don't need to worry
          // about write coalescing to MMIO regions
          new DBusSimplePlugin(
            catchAddressMisaligned = true,
            catchAccessFault = true
          ),

          // Instruction decoding
          new DecoderSimplePlugin(
            catchIllegalInstruction = true
          ),

          // Register file
          new RegFilePlugin(
            regFileReadyKind = plugin.SYNC,
            zeroBoot = false
          ),

          // Handles ADD/SUB/SLT/SLTU/XOR/OR/AND/LUI/AUIPC
          new IntAluPlugin,

          // Generates SRC1/SRC2/SRC_ADD/SRC_SUB/SRC_LESS
          new SrcPlugin(
            separatedAddSub = false,
            // Relax bypassing
            executeInsertion = true
          ),

          // Implements SLL/SRL/SRA using an iterative shift register.
          // For applications that do a lot of shifts, one may want to
          // instantiate the FullBarrelShifterPlugin instead
          new LightShifterPlugin,

          // Iterative implementation of multiply/divide instructions.
          // For faster execution, the unroll factor may be increased at the
          // cost of more logic.
          // For FPGAs with DSP blocks, for faster mul/div you can instantiate
          // the MulPlugin and DivPlugin instead
          new MulDivIterativePlugin(
            genMul = true,
            genDiv = true,
            mulUnrollFactor = 1,
            divUnrollFactor = 1
          ),

          // Checks the pipeline instruction dependencies and, if necessary
          // or possible, will stop the instruction in the decoding stage or
          // bypass the instruction results from the later stages of the
          // decode stage.
          new HazardSimplePlugin(
            bypassExecute           = true,
            bypassMemory            = true,
            bypassWriteBack         = true,
            bypassWriteBackBuffer   = true,
            pessimisticUseSrc       = false,
            pessimisticWriteRegFile = false,
            pessimisticAddressMatch = false
          ),

          // Handles JAL/JALR/BEQ/BNE/BLT/BGE/BLTU/BGEU
          new BranchPlugin(
            // If early branch is true, branch will be done in the execute stage
            // This is faster but hurts timings
            earlyBranch = false,
            // We want to trap if the CPU tries to jump to a misaligned address
            catchAddressMisaligned = true
          ),

          // Implementation of the Control and Status Registers.
          // We want to make sure that registers we use for interrupts, such as
          // mtvec and mcause, are accessible. We have also enabled mcycle
          // access for performance timing.
          new CsrPlugin(
            config = CsrPluginConfig(
                catchIllegalAccess = false,
                mvendorid      = null,
                marchid        = null,
                mimpid         = null,
                mhartid        = null,
                misaExtensionsInit = 66,
                misaAccess     = CsrAccess.NONE,
                mtvecAccess    = CsrAccess.READ_WRITE,
                mtvecInit      = 0x80000000l,
                xtvecModeGen   = true,
                mepcAccess     = CsrAccess.READ_WRITE,
                mscratchGen    = false,
                mcauseAccess   = CsrAccess.READ_ONLY,
                mbadaddrAccess = CsrAccess.READ_ONLY,
                mcycleAccess   = CsrAccess.READ_WRITE,
                minstretAccess = CsrAccess.NONE,
                ecallGen       = false,
                wfiGenAsWait   = false,
                ucycleAccess   = CsrAccess.READ_ONLY,
                uinstretAccess = CsrAccess.NONE
              )
          ),

          new YamlPlugin("cpu0.yaml")
        )
      )

      // CPU instantiation
      val cpu = new VexRiscv(cpuConfig)

      // CPU modifications to use a wishbone interface
      cpu.rework {
        for (plugin <- cpuConfig.plugins) plugin match {
          case plugin: IBusSimplePlugin => {
            plugin.iBus.setAsDirectionLess()
            master(plugin.iBus.toWishbone()).setName("iBusWishbone")
          }
          case plugin: IBusCachedPlugin => {
            plugin.iBus.setAsDirectionLess()
            master(plugin.iBus.toWishbone()).setName("iBusWishbone")
          }
          case plugin: DBusSimplePlugin => {
            plugin.dBus.setAsDirectionLess()
            master(plugin.dBus.toWishbone()).setName("dBusWishbone")
          }
          case plugin: DBusCachedPlugin => {
            plugin.dBus.setAsDirectionLess()
            master(plugin.dBus.toWishbone()).setName("dBusWishbone")
          }
          case _ =>
        }
      }

      cpu
    }
  }
}
