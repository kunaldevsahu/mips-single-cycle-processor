# Verification

## Strategy

The design is checked at three levels. Each level catches different kinds of bugs:

| Level | What is tested | How |
|---|---|---|
| **1. Unit** | each module on its own | 8 self-checking testbenches (221 checks) with hand-picked edge cases |
| **2. System** | the whole CPU running real programs | `tb_mips_top.v` runs 9 MIPS programs and compares every OUT value with an expected file |
| **3. Golden model** | the expected files themselves | `tools/iss.py`, a separate Python simulator, must produce the same outputs |

For every program, three independent sources agree: **hand calculation (`.expected`) = Python ISS = Verilog hardware**.

Run everything with:
```
python3 run_tests.py
```

## Level 1: unit tests

| Testbench | Module(s) | Owner | Checks | Key cases |
|---|---|---|---|---|
| `tb_alu` | alu | Vaibhav | 19 | add wrap-around, signed overflow (+ and −), SLT across sign boundary, SRA of negative, LUI |
| `tb_alu_control` | alu_control | Vaibhav | 19 | every ALUOp; every R-type funct |
| `tb_reg_file` | reg_file | Himanshu | 99 | reset, 31 registers × 2 ports, `$zero` write ignored, `we = 0`, write only at clock edge |
| `tb_sign_extend` | sign_extend | Himanshu | 9 | ±values, 0x7FFF, 0x8000, 0xFFFF, zero-extend mode |
| `tb_next_pc` | pc_reg, next_pc, mux | Pranav | 19 | beq/bne taken/not taken, backward branch, j, jr, jump priority, reset/stall |
| `tb_memory` | mem_controller, data_mem, mmio, instr_mem | Kevish | 23 | lw/sw, lb/lbu extension, sb byte lanes, line port, misaligned/unmapped, OUT/HALT/LED/CYCLE |
| `tb_control_unit` | control_unit | Kunal | 18 | all 18 control signals for every opcode + an illegal opcode |
| `tb_cache` | cache + data_mem | Kunal | 15 | miss then 3 hits in a block, write-through, byte merge, write miss, conflict eviction |
| **Total** | | | **221** | |

## Level 2: program tests

| Program | Cycles (= instructions) | Outputs | Cache read hit rate | AMAT* | Result |
|---|---|---|---|---|---|
| `instr_test` | 76 | 30 | 80.0 % | 5.00 | PASS |
| `array_sum` | 123 | 2 | 72.7 % | 6.45 | PASS |
| `max_array` | 107 | 2 | 72.7 % | 6.45 | PASS |
| `if_else` | 56 | 7 | 60.0 % | 9.00 | PASS |
| `fibonacci` | 2213 | 12 | 97.3 % | 1.53 | PASS |
| `bubble_sort` | 545 | 10 | 97.0 % | 1.60 | PASS |
| `string_ops` | 286 | 7 | 96.0 % | 1.80 | PASS |
| `cache_seq` | 1039 | 1 | 87.5 % | 3.50 | PASS |
| `cache_stride` | 127 | 1 | 0.0 % | 21.00 | PASS |

\* AMAT = 1 + miss rate × 20 cycles (hit time 1 cycle, assumed miss penalty 20 cycles).

**CPI = 1 in every program.** Cycle count equals instruction count, which is the defining property of a single-cycle processor.

### Cache observations

- **Spatial locality** (`cache_seq`, first pass): 1 miss followed by 3 hits in every 4-word block → 75 % hits on the first pass.
- **Temporal locality** (`cache_seq`, second pass): the 256-byte array fits in the 256-byte cache, so every second-pass read hits → 87.5 % overall.
- **Conflict misses** (`cache_stride`): addresses 256 bytes apart all map to line 0 and keep evicting each other → 0 % hits, AMAT 21 cycles. A set-associative cache would fix this.
- **Stack accesses** (`fibonacci`): the stack stays within a few blocks → 97 % hits.

## Checking that the tests can fail

Bugs were injected on purpose to make sure the tests notice them:

| Injected bug | Caught by |
|---|---|
| `sra` changed to a logical shift | `tb_alu` (SRA check) and `instr_test` program |
| `lb` sign-extension removed | `tb_memory` (lb sign-extend) and the `instr_test` and `string_ops` programs |
| Wrong value in `max_array.expected` | program test MISMATCH **and** the golden-model check disagreeing |

## Waveforms

```
python3 run_tests.py --run fibonacci --wave
gtkwave build/fibonacci.vcd
```
Useful signals: `dut.u_cpu.pc`, `dut.u_cpu.instr`, `dut.u_cpu.alu_result`, `dut.u_cpu.u_rf.regs`, `dut.u_cpu.u_ctrl.*`, `dut.out_valid`, `dut.out_data`, `dut.u_cache.read_hits`.

Use `--trace` to print every executed instruction, and `+REGS` (added automatically by `--run`) to dump the register file at the end.
