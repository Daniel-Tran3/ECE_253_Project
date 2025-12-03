# Details on the OS/WS Reconfigurable Streaming Multiprocessor

## Goals
- Don't make it *too* different from the professor's base instruction set
- Accomodate both output-stationary and weight-stationary computation schemes
  with generic-ish instructions
- To permit tiling over input channels, allow IFIFO to decide whether to load
  from psum memory or X memory
- Do not increase instruction width by more than 2 bits (so 36, 0-35)

## Instruction Set
The base instruction set is a strange variant of VLIW.
An instruction word is divided into subsections, each of which consistitutes
a specific type of instruction. For example, the first bit of every instruction
indicates that the core must accumulate the value output by the SRAM with the 
value currently stored in the SFP. 

The instruction words of the base instruction set is divided as follows:

Processing Element Control:
- bit 0: load kernel weights. Should be mutex with bit 1.
- bit 1: execute (passed to all PEs starting from top left, spreading down and
  right every cycle)

FIFO Control:
- bit 2: Command L0 fifo to queue up the value output by the X SRAM.
- bit 3: pop an element from L0 FIFO. Spreads to each row of the L0 FIFO
  top-down.
- bit 4: Command IFIFO to queue up the value output by the X SRAM. It is the
  programmer's responsibility to ensure that IFIFO receives the right value
  X SRAM (weight vs activation)
- bit 5: pop an element from IFIFO. Spreads to each row of the IFIFO 
  left-to-right.
- bit 6: pop an element from OFIFO.

Cache Control:
- bit 7-17: address of memory X (used for accumulators or weights) to store or
  load elements from
- bit 18: command memory X to perform a write at the address from bits 7-17.
- bit 19: command memory X to activate. If 19 is not set, 
- bits 20-30: pmem address to read/write from
- bit 31: write to psum memory at the address stored in bits 20-30
- bit 32: clock enable for psum memory.

SFU control/misc:
- bit 33: accumulate value at psum memory into psum register of SFU.

The new instruction set shall be slightly modified from this version:

- bit 0: OS flush/WS load
- bit 1: OS execute/WS execute
- ...
- bit 4: Command IFIFO to queue up the value output by X memory OR psum memory.
- ...
- bit 34 (execution_mode): high indicates OS mode; low indicates WS mode
- bit 35 (ififo_mode): 0 means IFIFO reads from X mem; 1 means IFIFO reads from psum mem.
- bit 36: 

(the rest is the same as base)

## Program Patterns
The programmer wants to perform the following tasks, which can be performed
using the following sequences of instructions:

Weight Stationary:
1. Write activations to X memory
2. Write weights to X memory at a different offset (or a different memory)
3. Read memory from weights into IFIFO while loading them into kernel
4. Load activations into L0 FIFO from X mem (can be merged into next step)
5. Execute in WS mode while continuously popping from L0 FIFO, writing back to
   PSUM memory as nij values become available.
6. Perform ReLU on all values in SFU  (Not necessary)

Output Stationary:
- Write activations to X memory
- Write weights to X memory at a different offset (or a different memory)
- Write **0s** to psum memory!  // This is to make tiling over outputs easier
- Load psums from memory into IFIFO and simultaneously write them to their
    private accumulators.  // combined with the previous step, resets accums to
    0 if we are just starting on a tile
- Reset PE local accumulator values to 0
- Simultaneously read weights into IFIFO, activations into L0 FIFO;
  execute simultaneously (with a one-cycle delay)
Tiling over input channels can be done by loading previously accumulated values
out of psum mem into the PEs' local accumulators. Tiling over outputs requires
new psums to be loaded in. Tiling is thus handled by the programmer.

As you can tell, tiling is most conveniently implemented by having an initial
starting point for memory (0). This way, we can treat the first tile like any
other tile, loading in PSUMs from the tile.
