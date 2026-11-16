# Program Counter, Branch/Jump Logic, Multiplexers and Test Programs

**Owner:** Pranav Singh ([@Pranav-Singh-Devloper](https://github.com/Pranav-Singh-Devloper))
**Files:** `rtl/pc_reg.v`, `rtl/next_pc.v`, `rtl/mux.v`, `tb/tb_next_pc.v`, `programs/*.asm`, `programs/*.expected`

## 1. Program counter: `pc_reg.v`

The PC holds the address of the instruction being executed. It is a 32-bit register (D flip-flops, Unit 2):

- **reset** → `0x0040_0000` (start of the text segment, same as MARS)
- every rising clock edge → loads `next_pc`
- **stall** (when the program has halted) → keeps its value

## 2. Next-PC logic: `next_pc.v`

Decides which instruction runs next. Four candidates, chosen by priority:

| Priority | Condition | Next PC | Addressing mode |
|---|---|---|---|
| 1 | `jr rs` | `rs` | register |
| 2 | `j` / `jal` | `{PC+4[31:28], target[25:0], 00}` | pseudo-direct |
| 3 | `beq` and zero = 1, or `bne` and zero = 0 | `PC + 4 + (signext(imm) << 2)` | PC-relative |
| 4 | otherwise | `PC + 4` | sequential |

- **Why `<< 2`?** Instructions are 4 bytes, so offsets and targets are counted in *words*. Shifting left by 2 converts words to bytes, and the 2 bits that are always 00 don't need to be stored. That gives 4× more range.
- **Why `PC + 4` and not `PC`?** By the time a branch is calculated, MIPS treats the PC as already pointing to the next instruction. The assembler uses the same rule: `offset = (target − (PC + 4)) / 4`.
- **Jump range:** the top 4 bits come from PC+4, so `j` can reach any address within the current 256 MB region.

## 3. Multiplexers: `mux.v`

`mux2` and `mux3`, parameterised by width (`#(W)`). Used for:
- **RegDst**: rt / rd / 31 (5-bit mux3)
- **ALUSrc**: rt_data / immediate (32-bit mux2)
- **MemtoReg**: ALU result / memory data / PC+4 (32-bit mux3)

## 4. Test programs: `programs/`

Every program writes its results to the OUT port and stops with a write to HALT. Each `.expected` file holds the correct outputs, **worked out by hand** from the C code in the program's header comment.

| Program | Syllabus topic | What it tests | Expected output |
|---|---|---|---|
| `instr_test.asm` | ISA, machine code | every one of the 29 instructions, including edge cases | 30 values |
| `array_sum.asm` | array storage using `sw`, loops | fill a[i] = i+1, then sum | 55, 10 |
| `max_array.asm` | maximum element in an array | max and min of 10 signed numbers | 99, −150 |
| `if_else.asm` | conditional statements | absolute value, counting negatives, `bgt` | 5 0 7 12 3 1 2 |
| `fibonacci.asm` | functions, `jal`/`jr`, stack | iterative fib(0..10) and **recursive** fib(10) | 0 1 1 2 3 5 8 13 21 34 55 55 |
| `bubble_sort.asm` | nested loops, C-to-MIPS | sort 10 numbers in memory | −3 5 11 12 22 25 34 47 64 90 |
| `string_ops.asm` | byte memory access | strlen, to-upper, reverse with `lb`/`lbu`/`sb` | 14, "MIPS", "ROSS", ... |
| `cache_seq.asm` | spatial/temporal locality | sequential reads → 87.5 % cache hits | 4160 |
| `cache_stride.asm` | conflict misses | 256-byte stride → 0 % cache hits | 16 |

### Calling convention used in `fibonacci.asm` (recursive)

```asm
fr_rec: addi  $sp, $sp, -12     # make room for 3 words on the stack
        sw    $ra, 0($sp)       # save return address (jal will overwrite it)
        sw    $a0, 4($sp)       # save n
        ...
        jal   fib_rec           # fib(n-1)
        sw    $v0, 8($sp)       # save fib(n-1)
        ...
        jal   fib_rec           # fib(n-2)
        lw    $t1, 8($sp)
        add   $v0, $v0, $t1     # fib(n-1) + fib(n-2)
        lw    $ra, 0($sp)       # restore and return
        addi  $sp, $sp, 12
        jr    $ra
```

## Testing

`tb_next_pc.v` (19 checks): sequential, beq/bne taken and not taken, a **backward** branch (negative offset), `j`, `jr`, jump priority over branch, PC reset value, load, stall and resume, and every mux input.

## Viva questions

1. **How is the branch target calculated?** PC + 4 + (sign-extended offset × 4).
2. **Why is the offset sign-extended?** So loops can branch **backwards** (negative offset).
3. **How does `jal` return?** It saves PC+4 in `$ra`; the function ends with `jr $ra`.
4. **Why does recursive code need a stack?** Each call overwrites `$ra` and `$a0`. They are saved in memory (`sw` to `$sp`) and restored (`lw`) before returning.
5. **What is the range of `beq`?** A 16-bit signed word offset: about ±32K instructions (±128 KB).
6. **Why does the PC start at 0x00400000?** It matches the MARS simulator's text segment, so the same programs and addresses work in both.
