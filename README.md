# Single-Cycle MIPS Processor with Memory Interface

**Course:** Modern Computer Architecture (MCA) · **Team:** Vaibhav Ke Veer · **Group:** B

A 32-bit MIPS processor written in Verilog. Every instruction finishes in **one clock cycle**. The processor connects to a **memory interface** that has:

- an address decoder,
- byte-level loads and stores,
- memory-mapped I/O,
- a direct-mapped **data cache** that counts hits and misses and reports AMAT.

The project comes with its own **assembler**, a **reference simulator** used as the golden model, and an automated **test suite**. That suite has 8 module testbenches and 9 MIPS programs.

```
$ python3 run_tests.py
  PASS  tb_alu (19 tests)            PASS  array_sum     123 cycles, cache hit rate 72.7 %
  PASS  tb_alu_control (19 tests)    PASS  bubble_sort   545 cycles, cache hit rate 97.0 %
  PASS  tb_reg_file (99 tests)       PASS  cache_seq    1039 cycles, cache hit rate 87.5 %
  PASS  tb_sign_extend (9 tests)     PASS  cache_stride  127 cycles, cache hit rate  0.0 %
  PASS  tb_next_pc (19 tests)        PASS  fibonacci    2213 cycles, cache hit rate 97.3 %
  PASS  tb_memory (23 tests)         PASS  if_else        56 cycles, cache hit rate 60.0 %
  PASS  tb_control_unit (18 tests)   PASS  instr_test     76 cycles, cache hit rate 80.0 %
  PASS  tb_cache (15 tests)          PASS  max_array     107 cycles, cache hit rate 72.7 %
                                     PASS  string_ops    286 cycles, cache hit rate 96.0 %
 17/17 tests passed
```

---

## Team

| Member | Roll No. | GitHub | Responsibility |
|---|---|---|---|
| **Kunal Dev Sahu** (lead) | 2401010244 | [@kunaldevsahu](https://github.com/kunaldevsahu) | Main control unit, data cache, CPU integration, system testbench, assembler, reference simulator, test runner, documentation |
| **Vaibhav Singh** | 2401020074 | [@VaibhavSingh50](https://github.com/VaibhavSingh50) | ALU and ALU control unit |
| **Himanshu Pal** | 2401010190 | [@HimanshuPal29](https://github.com/HimanshuPal29) | Register file and sign extender |
| **Kevish Sewliya** | 2401010224 | [@kevish-dev](https://github.com/kevish-dev) | Memory interface: instruction memory, data memory, memory controller, memory-mapped I/O |
| **Pranav Singh** | 2401010333 | [@Pranav-Singh-Devloper](https://github.com/Pranav-Singh-Devloper) | Program counter, branch/jump logic, multiplexers, test programs |

[docs/TEAM.md](docs/TEAM.md) lists every file and what each person built.

---

## Features

| | |
|---|---|
| **ISA** | 29 MIPS instructions: R-type, I-type and J-type ([list](docs/ARCHITECTURE.md#2-instruction-set)) |
| **Datapath** | Classic single-cycle design, CPI = 1 |
| **Architecture** | Harvard: separate 4 KB instruction memory and 4 KB data memory |
| **Memory interface** | Address decoder, little-endian byte lanes (`lb`, `lbu`, `sb`), detects misaligned and unmapped accesses |
| **Memory-mapped I/O** | OUT port, HALT, LED register and cycle counter at `0xFFFF_0000` |
| **Data cache** | Direct-mapped, 16 lines × 16 B, write-through. Counts hits and misses and computes AMAT |
| **Tools** | Two-pass assembler (with pseudo-instructions), Python reference simulator (ISS), one-command test runner |
| **Verification** | 221 unit checks plus 9 programs, each checked against hand-computed results **and** the golden model |

---

## Quick start

### 1. Install the tools

| OS | Command |
|---|---|
| Ubuntu / WSL | `sudo apt install iverilog gtkwave python3` |
| macOS | `brew install icarus-verilog` (GTKWave: `brew install --cask gtkwave`) |
| Windows | Install Icarus Verilog from <https://bleyer.org/icarus/> (tick "add to PATH"; GTKWave is included) and Python 3 from python.org |

### 2. Run every test

```bash
python3 run_tests.py          # Windows: python run_tests.py
```

### 3. Run one program and look at the waveform

```bash
python3 run_tests.py --run bubble_sort            # prints OUT values, cache stats, registers
python3 run_tests.py --run bubble_sort --wave     # also writes build/bubble_sort.vcd
gtkwave build/bubble_sort.vcd
```

### 4. Write your own program

Put a `.asm` file in `programs/`. Write results with `sw $reg, 0($s7)` (where `$s7 = 0xFFFF0000`) and finish with `sw $zero, 4($s7)` to halt. Then run:

```bash
python3 tools/iss.py programs/myprog.asm      # see what it should output
python3 run_tests.py --run myprog             # run it on the hardware
```

If you add a `programs/myprog.expected` file, the test suite checks the program automatically.

---

## Repository layout

```
rtl/                      Verilog source of the processor
  defines.vh              opcodes, ALU codes, memory map            (Kunal)
  mips_top.v              system: CPU + memories + cache + I/O      (Kunal)
  mips_cpu.v              single-cycle datapath                     (Kunal)
  control_unit.v          main control                              (Kunal)
  cache.v                 direct-mapped data cache                  (Kunal)
  alu.v, alu_control.v                                              (Vaibhav)
  reg_file.v, sign_extend.v                                         (Himanshu)
  instr_mem.v, data_mem.v, mem_controller.v, mmio.v                 (Kevish)
  pc_reg.v, next_pc.v, mux.v                                        (Pranav)
tb/                       one testbench per module + full-system testbench
programs/                 MIPS test programs (.asm) + expected outputs  (Pranav)
tools/assembler.py        MIPS assembler                            (Kunal)
tools/iss.py              instruction-set simulator / golden model  (Kunal)
run_tests.py, Makefile    build and test automation                 (Kunal)
docs/                     architecture, verification, report, team, module notes
```

## Documentation

| Document | Contents |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Datapath diagram, instruction set and encodings, control-signal table, memory map, cache design |
| [docs/VERIFICATION.md](docs/VERIFICATION.md) | Test strategy, every test and its result, cache measurements |
| [docs/REPORT.md](docs/REPORT.md) | Project report: objectives, design, results, how it maps to the syllabus, future work |
| [docs/TEAM.md](docs/TEAM.md) | Who built what |
| [docs/modules/](docs/modules) | One explanation per member's module, with viva questions |
