# Project Report: Single-Cycle MIPS Processor with Memory Interface

**Course:** Modern Computer Architecture (MCA)
**Team:** Vaibhav Ke Veer (Group B)
**PDF version:** [Project_Report.pdf](Project_Report.pdf) (with datapath diagram, waveform and results)

**Members:** Kunal Dev Sahu (2401010244) · Vaibhav Singh (2401020074) · Himanshu Pal (2401010190) · Kevish Sewliya (2401010224) · Pranav Singh (2401010333)

---

## 1. Objective

To design, implement and verify a 32-bit **single-cycle MIPS processor** in Verilog HDL, connected to a **memory interface** that supports byte-addressable memory, memory-mapped I/O and a data cache. The processor must run real MIPS programs (translated from C) and give correct results in simulation.

## 2. Scope

| Item | Implemented |
|---|---|
| Instruction formats | R-type, I-type, J-type |
| Instructions | 29: arithmetic, logical, shifts, compare, `lui`, word and byte loads/stores, `beq`/`bne`, `j`/`jal`/`jr` |
| Datapath | single-cycle, CPI = 1 |
| Memory organisation | Harvard: 4 KB instruction memory + 4 KB data memory |
| Memory interface | address decoder, byte lanes, load sign/zero extension, error detection |
| I/O | memory-mapped OUT, HALT, LED, cycle counter |
| Cache | 256 B direct-mapped, 16-byte blocks, write-through, hit/miss statistics |
| Tools | assembler, instruction-set simulator, automated test runner |

## 3. Design

The full design is in [ARCHITECTURE.md](ARCHITECTURE.md). In summary:

1. **Fetch**: the PC (reset to 0x00400000) addresses the instruction memory.
2. **Decode**: the control unit decodes the opcode; the register file reads `rs` and `rt`; the 16-bit immediate is sign- or zero-extended.
3. **Execute**: the ALU control picks the ALU operation (two-level decoding); the ALU computes a result, an address or a comparison.
4. **Memory**: the memory controller sends the access to the cache/RAM or to the I/O registers and formats bytes.
5. **Write-back and next PC**: at the rising clock edge the result is written to the register file and the PC moves to PC+4, the branch target, the jump target or `rs`.

### Module breakdown

| Module | Owner | Type |
|---|---|---|
| `alu`, `alu_control` | Vaibhav Singh | combinational |
| `reg_file` | Himanshu Pal | sequential (write) / combinational (read) |
| `sign_extend` | Himanshu Pal | combinational |
| `instr_mem`, `data_mem`, `mem_controller`, `mmio` | Kevish Sewliya | memory / combinational / sequential |
| `pc_reg`, `next_pc`, `mux2`, `mux3` | Pranav Singh | sequential / combinational |
| `control_unit`, `cache`, `mips_cpu`, `mips_top` | Kunal Dev Sahu | combinational / sequential / structural |

## 4. Verification and results

Full details: [VERIFICATION.md](VERIFICATION.md).

- **221 unit-level checks** across 8 testbenches: all pass.
- **9 programs** on the complete processor: all pass. Each one is checked against hand-computed outputs *and* an independent Python reference simulator.
- **CPI = 1** measured on every program (cycle count = instruction count).
- **Injected-bug tests** confirm the testbenches catch real errors.

| Program | Instructions | Cache hit rate | Result |
|---|---|---|---|
| instr_test | 76 | 80.0 % | PASS |
| array_sum | 123 | 72.7 % | PASS |
| max_array | 107 | 72.7 % | PASS |
| if_else | 56 | 60.0 % | PASS |
| fibonacci (recursive) | 2213 | 97.3 % | PASS |
| bubble_sort | 545 | 97.0 % | PASS |
| string_ops | 286 | 96.0 % | PASS |
| cache_seq | 1039 | 87.5 % | PASS |
| cache_stride | 127 | 0.0 % | PASS |

### Cache experiment

| Access pattern | Hit rate | AMAT (1 + m × 20) |
|---|---|---|
| Sequential, array fits in cache (`cache_seq`) | 87.5 % | 3.50 cycles |
| Stride = cache size (`cache_stride`) | 0.0 % | 21.00 cycles |

The same number of loads costs **6× more** average memory time when the access pattern has no locality. This is the **memory wall** that caches are built to hide.

## 5. Mapping to the syllabus

| Unit | Topic | Where it appears in the project |
|---|---|---|
| 1 | Two's complement, binary arithmetic, overflow | ALU adder-subtractor, overflow flag, signed SLT |
| 1 | Combinational circuits: adders, multiplexers | ALU, `mux2`/`mux3`, next-PC adders |
| 2 | Flip-flops, registers, clock edge | register file, PC, data memory, cache state, MMIO registers |
| 2 | Verilog HDL modules | the whole design (15 modules) and testbenches |
| 2 | Sign extender (practical) | `sign_extend.v` |
| 3 | Harvard architecture | separate instruction and data memories |
| 3 | CPU components: ALU, control unit, registers, PC | each one is a module |
| 3 | Instruction cycle: fetch, decode, execute | all done in one clock cycle |
| 3 | ISA, instruction formats, addressing modes | R/I/J formats; register, immediate, base+offset, PC-relative, pseudo-direct addressing |
| 4 | MIPS registers and instructions | 29 instructions, standard register names in the assembler |
| 4 | Machine code (e.g. `sw $t1, 4($t0)` → 0xAD090004) | the assembler and `.lst` listing files |
| 4 | Loops, if-else, C-to-MIPS, maximum of an array | `array_sum`, `if_else`, `max_array`, `bubble_sort`, `fibonacci` |
| 5 | Single-cycle datapath, control unit, register file, memories | the core of the project |
| 5 | Memory hierarchy, cache hit/miss, locality, AMAT | `cache.v`, `cache_seq`/`cache_stride` experiment |
| 6 | Pipelining (future work) | see §7 below |

## 6. Design challenges and how they were handled

| Challenge | How the design handles it |
|---|---|
| Signed `slt` is wrong for very large or very small numbers if it only looks at the sign of `a − b` | The sign of `a − b` is wrong when the subtraction overflows. Compare signs first. |
| `andi $t0, $t1, 0xFF00` clears the wrong bits if the immediate is sign-extended | Logical immediates must be **zero**-extended. Added the `ext_op` control signal. |
| `sb` must not overwrite the other 3 bytes of the word | Added per-byte write enables to data memory; the controller copies the byte to all lanes. |
| `jr` looks like a normal R-type and would write a register | The control unit also checks `funct == 0x08`. |
| A simulation needs a clean way to stop when the program ends | Added the HALT I/O register; when halted, the PC stalls and writes are blocked. |
| The expected results could themselves be wrong | Built an independent Python ISS; three sources must agree. |

## 7. Future work

1. **Pipelining (5 stages: IF, ID, EX, MEM, WB).** The single-cycle clock must fit the slowest instruction (`lw`). A pipeline overlaps instructions so the clock only has to fit the slowest *stage*. Throughput could rise towards 5× in theory, but it needs:
   - pipeline registers between stages,
   - **data forwarding** and **stalls** for data hazards (e.g. `lw` followed by a dependent `add`),
   - **branch prediction** or flushing for control hazards.
2. **Multi-cycle implementation**: each instruction uses only the cycles it needs, and one memory/ALU can be shared.
3. **Set-associative cache**: removes the conflict misses seen in `cache_stride`.
4. **Real miss penalty**: make memory slower than the cache and stall the CPU on misses, so AMAT shows up in the cycle count.
5. **Exceptions**: overflow trap, illegal instruction, misaligned address.
6. **FPGA implementation**: the design is synthesizable. Load a program with the `IMEM_FILE` parameter and drive board LEDs from the LED register.

## 8. Conclusion

We designed and verified a working single-cycle MIPS processor with a full memory interface. It runs 29 MIPS instructions with CPI = 1, handles word and byte memory access, talks to I/O through memory-mapped registers, and measures cache behaviour. All 17 tests pass. The project brought together digital logic, sequential circuits, Verilog, the MIPS ISA, datapath and control design, and the memory hierarchy from the course.

## References

1. D. A. Patterson and J. L. Hennessy, *Computer Organization and Design: The Hardware/Software Interface (MIPS Edition)*, Morgan Kaufmann. Chapter 4 (The Processor), Chapter 5 (Memory Hierarchy).
2. MIPS32 Architecture for Programmers, Volume II: The MIPS32 Instruction Set.
3. MARS MIPS simulator, Missouri State University.
4. Icarus Verilog and GTKWave documentation.
