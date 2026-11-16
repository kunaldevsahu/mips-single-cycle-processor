# Memory Interface

**Owner:** Kevish Sewliya ([@kevish-dev](https://github.com/kevish-dev))
**Files:** `rtl/instr_mem.v`, `rtl/data_mem.v`, `rtl/mem_controller.v`, `rtl/mmio.v`, `tb/tb_memory.v`

This is the "Memory Interface" part of the project title. The CPU produces only an address, data and a few control bits. Everything that turns that into an actual memory or device access happens here.

## 1. Instruction memory: `instr_mem.v`

- 1024 words (4 KB), **read-only** during execution.
- Loaded from a `.hex` file made by the assembler (`$readmemh`).
- Indexed by `addr[11:2]`: instructions are 4 bytes and aligned, so the lowest 2 bits are always 00.
- The read is combinational, so the instruction is available in the same cycle (needed for single-cycle).
- Kept separate from data memory: a **Harvard architecture** (Unit 3), so instruction fetch and `lw`/`sw` never compete for the memory.

## 2. Data memory: `data_mem.v`

- 1024 words (4 KB) mapped at `0x1001_0000` (same as the MARS `.data` segment).
- **4 byte enables** (`be[3:0]`). Each byte of a word can be written separately, which is how `sb` changes only one byte.
- Writes on the rising clock edge; reads are combinational.
- An extra **line port** returns 4 consecutive words (one cache block) so the cache can fill a whole block at once.

## 3. Memory controller: `mem_controller.v`

The address decoder and data formatter.

### Address decoding
| Condition | Goes to |
|---|---|
| `addr[31:12] == 0x10010` | data RAM (through the cache) |
| `addr[31:16] == 0xFFFF` | memory-mapped I/O |
| anything else | `bad_addr = 1` (error) |

### Stores: byte lanes (little-endian)
| Instruction | addr[1:0] | Byte enables | Data sent |
|---|---|---|---|
| `sw` | 00 | 1111 | rt |
| `sb` | 00 | 0001 | rt[7:0] copied to all 4 lanes |
| `sb` | 01 | 0010 | " |
| `sb` | 10 | 0100 | " |
| `sb` | 11 | 1000 | " |

Copying the byte to every lane means the memory doesn't need a shifter. The byte enable chooses which lane is actually written.

### Loads: byte select and extension
```verilog
byte_sel = word >> (8 * addr[1:0]);                // pick the byte
lb  : {{24{byte_sel[7]}}, byte_sel}                 // sign-extend
lbu : {24'b0, byte_sel}                             // zero-extend
```
Example: memory holds 0x12349C78 and `lb` reads offset 1 → byte 0x9C → 0xFFFFFF9C (−100); `lbu` gives 0x0000009C (156).

### Error detection
- `misaligned`: a **word** access whose address is not a multiple of 4. MIPS requires aligned words. The write is blocked and the testbench reports it.
- `bad_addr`: the address is not mapped to any device.

## 4. Memory-mapped I/O: `mmio.v`

A program uses ordinary `sw`/`lw` instructions to talk to devices. This is **memory-mapped I/O**, so there are no special I/O instructions.

| Address | Register | Behaviour |
|---|---|---|
| `0xFFFF_0000` | OUT | write → value appears on `out_data` with `out_valid = 1` for one cycle; the testbench prints and checks it |
| `0xFFFF_0004` | HALT | write → `halted = 1`; the PC freezes and register/memory writes are blocked |
| `0xFFFF_0008` | LED | 8-bit register; could drive LEDs on an FPGA board |
| `0xFFFF_000C` | CYCLE | read → number of clock cycles since reset |

Example program fragment:
```asm
lui  $s7, 0xFFFF        # $s7 = 0xFFFF0000
sw   $v0, 0($s7)        # print $v0
sw   $zero, 4($s7)      # halt
```

## Testing

`tb_memory.v` (23 checks) connects the controller, RAM, MMIO and instruction memory and tests:
word store/load, the last word of RAM, `lbu` of bytes 0 and 3, `lb` sign extension vs `lbu` zero extension, `sb` changing only one byte (twice), the 4-word line port, misaligned and unmapped detection, OUT strobe and data, I/O writes **not** reaching RAM, LED register, cycle counter, HALT, and instruction memory reads.

The `string_ops.asm` program then tests the same features from real MIPS code (strlen, upper-case, string reverse).

## Viva questions

1. **What is memory-mapped I/O?** Devices get addresses in the memory space, so the CPU uses normal load/store instructions to reach them. The address decoder sends each access to the right device.
2. **Harvard vs Von Neumann?** Harvard has separate instruction and data memories. A single-cycle CPU needs this, because it fetches an instruction and may access data in the same cycle.
3. **How does `sb` write one byte without changing the others?** The byte enables: only the selected byte lane gets written.
4. **What is little-endian?** The lowest-addressed byte is the least significant byte of the word. "MIPS" stored as bytes M I P S reads back as the word 0x5350494D.
5. **Why must `lw` addresses be multiples of 4?** The memory is organised in 32-bit words. A misaligned word would span two memory words, which would need two accesses.
6. **What happens on a write to `0xFFFF0004`?** The HALT flag sets, the PC stops updating and further writes are blocked, so the simulation ends cleanly.
