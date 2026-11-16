# Team and Contributions

**Team:** Vaibhav Ke Veer · **Group:** B · **Course:** Modern Computer Architecture
**Project:** Single-Cycle MIPS Processor with Memory Interface

| Member | Roll No. | Email | GitHub |
|---|---|---|---|
| Kunal Dev Sahu | 2401010244 | kunal.sahu2024@nst.rishihood.edu.in | [@kunaldevsahu](https://github.com/kunaldevsahu) |
| Vaibhav Singh | 2401020074 | vaibhav.singh2024@nst.rishihood.edu.in | [@VaibhavSingh50](https://github.com/VaibhavSingh50) |
| Himanshu Pal | 2401010190 | himanshu.pal2024@nst.rishihood.edu.in | [@HimanshuPal29](https://github.com/HimanshuPal29) |
| Kevish Sewliya | 2401010224 | kevish.sewliya2024@nst.rishihood.edu.in | [@kevish-dev](https://github.com/kevish-dev) |
| Pranav Singh | 2401010333 | pranav.singh2024@nst.rishihood.edu.in | [@Pranav-Singh-Devloper](https://github.com/Pranav-Singh-Devloper) |

---

## Kunal Dev Sahu: integration, control, cache, tools

**Role:** Defined the shared interfaces, built the control unit and cache, joined all modules into the working CPU, and built the verification and tooling.

| File | What it does |
|---|---|
| `rtl/defines.vh` | Shared constants: opcodes, funct codes, ALU codes, memory map. The "contract" every module follows |
| `rtl/control_unit.v` | Main control: decodes the opcode into the 18 control signals of the datapath |
| `rtl/cache.v` | Direct-mapped data cache (16 × 16 B, write-through) with hit/miss counters |
| `rtl/mips_cpu.v` | Single-cycle datapath that connects every module |
| `rtl/mips_top.v` | Whole system: CPU + memories + memory interface + cache + I/O |
| `tb/tb_control_unit.v` | Checks the control signals of every opcode |
| `tb/tb_cache.v` | Checks hits, misses, write-through, byte merge and conflict eviction |
| `tb/tb_mips_top.v` | Runs a full program, checks outputs, prints cache statistics and AMAT |
| `tools/assembler.py` | Two-pass MIPS assembler with pseudo-instructions |
| `tools/iss.py` | Python instruction-set simulator used as the golden model |
| `run_tests.py`, `Makefile` | One command to build and run every test |
| `README.md`, `docs/*` | Architecture, verification, report and team docs |

Detail: [modules/control_and_cache.md](modules/control_and_cache.md)

## Vaibhav Singh: ALU and ALU control

**Role:** The arithmetic/logic core of the processor.

| File | What it does |
|---|---|
| `rtl/alu.v` | 32-bit ALU with 11 operations: add/sub on one adder-subtractor, and, or, xor, nor, signed slt, sll, srl, sra, lui. Zero and overflow flags |
| `rtl/alu_control.v` | Second-level decoder: turns ALUOp + funct into the 4-bit ALU operation |
| `tb/tb_alu.v` | 19 checks, including overflow and signed-compare edge cases |
| `tb/tb_alu_control.v` | 19 checks covering every ALUOp/funct combination |
| `docs/modules/alu.md` | Module explanation and viva notes |

Detail: [modules/alu.md](modules/alu.md)

## Himanshu Pal: register file and sign extender

**Role:** Processor storage and immediate handling.

| File | What it does |
|---|---|
| `rtl/reg_file.v` | 32 × 32-bit register file: 2 combinational read ports, 1 clocked write port, `$zero` hard-wired |
| `rtl/sign_extend.v` | Widens 16-bit immediates to 32 bits: sign-extend (arithmetic, loads, branches) or zero-extend (andi/ori/xori) |
| `tb/tb_reg_file.v` | 99 checks: reset, all registers on both ports, `$zero`, write enable, clock-edge timing |
| `tb/tb_sign_extend.v` | 9 checks: positive, negative and boundary values in both modes |
| `docs/modules/register_file.md` | Module explanation and viva notes |

Detail: [modules/register_file.md](modules/register_file.md)

## Kevish Sewliya: memory interface

**Role:** Everything between the CPU and the memories and devices.

| File | What it does |
|---|---|
| `rtl/instr_mem.v` | 4 KB instruction ROM loaded from a hex file (Harvard architecture) |
| `rtl/data_mem.v` | 4 KB data RAM with per-byte write enables and a 4-word line port for the cache |
| `rtl/mem_controller.v` | Address decoder (RAM / I/O / unmapped), byte lanes for `sb`, byte select and sign/zero extension for `lb`/`lbu`, misaligned-access detection |
| `rtl/mmio.v` | Memory-mapped I/O: OUT port, HALT, LED register, cycle counter |
| `tb/tb_memory.v` | 23 checks of the whole memory interface |
| `docs/modules/memory_interface.md` | Module explanation and viva notes |

Detail: [modules/memory_interface.md](modules/memory_interface.md)

## Pranav Singh: PC, branch/jump logic, multiplexers, test programs

**Role:** Instruction sequencing and the software that tests the hardware.

| File | What it does |
|---|---|
| `rtl/pc_reg.v` | Program counter: reset to 0x00400000, loads next PC each cycle, stalls when halted |
| `rtl/next_pc.v` | Chooses the next PC: PC+4, branch target (beq/bne), jump target (j/jal), or register (jr) |
| `rtl/mux.v` | Parameterised 2:1 and 3:1 multiplexers used in the datapath |
| `tb/tb_next_pc.v` | 19 checks: every PC source, backward branches, priority, stall, muxes |
| `programs/*.asm` | 9 MIPS test programs: instruction test, array sum, max/min, if-else, Fibonacci (recursive), bubble sort, string operations, two cache demos |
| `programs/*.expected` | Hand-computed correct outputs for each program |
| `docs/modules/pc_and_programs.md` | Module explanation and viva notes |

Detail: [modules/pc_and_programs.md](modules/pc_and_programs.md)

---

## How we worked

1. **Interface first:** Kunal pushed `defines.vh`, the port lists and the test runner, so everyone built against the same contract.
2. **Feature branches:** each member built their module and its testbench on their own branch (`feature/alu`, `feature/register-file`, `feature/memory-interface`, `feature/pc-and-programs`) and opened a pull request.
3. **Review and merge:** each pull request was reviewed and merged into `main`.
4. **Integration:** Kunal connected all modules in `mips_cpu.v` / `mips_top.v`, then ran the full-system tests until all 17 passed.
