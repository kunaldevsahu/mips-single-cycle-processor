# Control Unit, Data Cache, CPU Integration and Tools

**Owner:** Kunal Dev Sahu ([@kunaldevsahu](https://github.com/kunaldevsahu))
**Files:** `rtl/defines.vh`, `rtl/control_unit.v`, `rtl/cache.v`, `rtl/mips_cpu.v`, `rtl/mips_top.v`, `tb/tb_control_unit.v`, `tb/tb_cache.v`, `tb/tb_mips_top.v`, `tools/assembler.py`, `tools/iss.py`, `run_tests.py`, `Makefile`

## 1. Main control unit: `control_unit.v`

The "brain" of the datapath. It reads the **opcode** (and `funct` only to spot `jr`) and sets every control signal. It is purely **combinational**: a big `case` on the opcode, starting from safe defaults (no writes), so an unknown opcode acts like a `nop`.

The full truth table is in [ARCHITECTURE.md §4](../ARCHITECTURE.md#4-control-signals). Key ideas:

| Signal | Why it exists |
|---|---|
| `reg_dst` | R-type writes **rd**, I-type writes **rt**, `jal` writes **$31** |
| `alu_src` | second ALU operand is a register (R-type, branches) or the immediate (I-type) |
| `mem_to_reg` | write back the ALU result, the loaded value, or PC+4 (`jal`) |
| `reg_write`, `mem_write` | only instructions that should change state turn these on |
| `mem_byte`, `mem_unsigned` | tell the memory interface about `lb`/`lbu`/`sb` |
| `branch`, `branch_ne`, `jump`, `jump_reg` | steer the next-PC logic |
| `ext_op` | sign-extend (arithmetic) vs zero-extend (`andi`/`ori`/`xori`) |
| `alu_op` | 3-bit hint to the ALU control (two-level decoding) |

## 2. Data cache: `cache.v`

A **direct-mapped** cache between the memory controller and the data RAM.

```
 address: | tag (24 bits) [31:8] | index (4 bits) [7:4] | word (2 bits) [3:2] | byte [1:0] |
 16 lines, each: valid bit + 24-bit tag + 4 words (16 bytes)
```

- **Hit** = `valid[index] && tag[index] == tag`.
- **Read miss** → the whole 4-word block is copied from RAM (**spatial locality**: the next 3 words will hit).
- **Write-through**: every store also goes to RAM, so RAM is never stale. A write hit updates the cached word too, merging bytes for `sb`. A write miss doesn't allocate.
- **Counters**: read hits, read misses, write hits, write misses.

Because RAM answers in the same cycle in a single-cycle design, the cache is used to **measure** locality. The testbench prints:

```
Cache: reads 264 (hits 257, misses 7), writes 264 (hits 239, misses 25)
Read hit rate = 97.3 %   AMAT = 1 + 0.027 x 20 = 1.53 cycles
```

| Program | Read hit rate | Why |
|---|---|---|
| `cache_seq` | 87.5 % | 1 miss per 4-word block on the first pass (spatial); second pass all hits (temporal) |
| `cache_stride` | 0 % | every address maps to line 0 → each read evicts the previous block (conflict misses) |
| `fibonacci` | 97.3 % | the stack stays in a few blocks (temporal locality) |

## 3. CPU integration: `mips_cpu.v` and `mips_top.v`

`mips_cpu.v` wires every member's module into the single-cycle datapath (see the diagram in ARCHITECTURE.md). Two details:
- When `halt` = 1, `RegWrite` and `MemWrite` are forced to 0 and the PC stalls, so the processor freezes cleanly.
- The CPU sends only address, data and control bits. Memory decisions all live in Kevish's memory interface.

`mips_top.v` is the whole system: CPU + instruction memory + memory controller + cache + data memory + MMIO.

## 4. Tools

### Assembler: `tools/assembler.py`
Two-pass assembler:
1. **Pass 1**: finds every label and its address. Pseudo-instructions can expand to 2 real instructions, so it has to know their size.
2. **Pass 2**: encodes each instruction into 32-bit machine code. Branch offsets = (target − (PC+4)) / 4; jump targets = address / 4.

Produces `.hex` (instructions), `_data.hex` (`.data` segment) and `.lst` (listing with addresses and machine code).

Example: `sw $t1, 4($t0)` → opcode 0x2B, rs = 8, rt = 9, imm = 4 → `101011 01000 01001 0000000000000100` = **0xAD090004**.

### Reference simulator: `tools/iss.py`
An **Instruction Set Simulator** in Python. It executes the program one instruction at a time, from the ISA definition, without looking at the Verilog. It acts as an independent **golden model**: `run_tests.py` checks that the ISS, the hand-computed `.expected` files and the hardware all agree.

### Test runner: `run_tests.py`
Compiles and runs all 8 unit testbenches, assembles every program, runs it on `tb_mips_top`, checks the outputs, and prints a PASS/FAIL table with cycle counts and cache hit rates.

## Viva questions

1. **What does the control unit do for `lw`?** ALUSrc = 1 (add offset), MemRead = 1, MemtoReg = 01 (memory data), RegWrite = 1, RegDst = rt.
2. **Why is `jr` detected using `funct`?** It is an R-type instruction (opcode 0). Without checking funct, the control unit would treat it as a normal R-type and write a register.
3. **What is a direct-mapped cache?** Each memory block can go into exactly one cache line, chosen by the index bits.
4. **What are the three kinds of cache miss?** Compulsory (first access), capacity (cache too small), conflict (two blocks share a line, as in `cache_stride`).
5. **Write-through vs write-back?** Write-through updates memory on every store (simple, memory always correct). Write-back updates only the cache and writes to memory when the line is evicted (faster, needs a dirty bit).
6. **What is AMAT?** Average Memory Access Time = hit time + miss rate × miss penalty.
7. **Why a separate reference simulator?** If two independent implementations (Python ISS and Verilog RTL) give the same results, a shared misunderstanding is much less likely.
