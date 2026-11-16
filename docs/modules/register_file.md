# Register File and Sign Extender

**Owner:** Himanshu Pal ([@HimanshuPal29](https://github.com/HimanshuPal29))
**Files:** `rtl/reg_file.v`, `rtl/sign_extend.v`, `tb/tb_reg_file.v`, `tb/tb_sign_extend.v`

## Register file: what it does

MIPS has **32 general-purpose registers**, each 32 bits wide (`$zero`, `$at`, `$v0`, `$t0`, `$s0`, `$sp`, `$ra`, ...). The register file stores them.

In one clock cycle a single-cycle CPU must:
- **read two registers** (`rs` and `rt`) for the ALU, and
- **write one register** (`rd`, `rt` or `$ra`) with the result.

So the register file has **two read ports and one write port**.

| Port | Dir | Width | Meaning |
|---|---|---|---|
| `clk`, `rst` | in | 1 | clock, synchronous reset (clears all registers) |
| `ra1`, `ra2` | in | 5 | read addresses (rs, rt) |
| `rd1`, `rd2` | out | 32 | read data |
| `we` | in | 1 | write enable (RegWrite from control) |
| `wa` | in | 5 | write address |
| `wd` | in | 32 | write data |

### How it works

```verilog
reg [31:0] regs [0:31];                                  // 32 registers made of D flip-flops
assign rd1 = (ra1 == 0) ? 0 : regs[ra1];                 // read: combinational
always @(posedge clk) if (we && wa != 0) regs[wa] <= wd; // write: on clock edge
```

- **Reads are combinational** (like a multiplexer). The value appears as soon as the address is given, within the same cycle.
- **Writes are synchronous** (Unit 2: flip-flops / registers). The new value is stored on the rising clock edge at the **end** of the cycle. An instruction like `add $t0, $t0, $t1` therefore reads the old `$t0` and writes the new one at the edge, with no conflict.
- **`$zero` is hard-wired to 0.** Writes to register 0 are ignored and reading it always gives 0. That is why `add $t0, $t1, $zero` works as a move.

## Sign extender: what it does

I-type instructions carry a **16-bit immediate**, but the ALU works on **32 bits**. The extender widens it:

| `ext_op` | Mode | Example: imm = 0xFFFB | Used by |
|---|---|---|---|
| 1 | **sign-extend**: copy bit 15 into bits 31:16 | 0xFFFFFFFB (= −5) | addi, slti, lw, sw, lb, sb, beq, bne |
| 0 | **zero-extend**: fill bits 31:16 with 0 | 0x0000FFFB (= 65531) | andi, ori, xori |

```verilog
assign imm_ext = ext_op ? {{16{imm[15]}}, imm} : {16'b0, imm};
```

Sign extension keeps the **value** of a two's-complement number the same. That is needed for negative offsets such as `lw $t0, -4($sp)` and for backward branches. Logical instructions use zero extension because they treat the immediate as a bit pattern, not a number.

## Testing

- `tb_reg_file.v` (99 checks): every register is 0 after reset; each of the 31 registers is written and read back through **both** ports; `$zero` ignores writes; `we = 0` blocks writes; a write takes effect only **at** the clock edge, not before.
- `tb_sign_extend.v` (9 checks): positive, negative, 0x7FFF, 0x8000, −1, and zero-extend mode.

## Viva questions

1. **Why two read ports?** R-type and branch instructions need `rs` and `rt` in the same cycle.
2. **Why is the write synchronous but the read asynchronous?** Reads must finish within the cycle so the ALU can use the values. Writing at the clock edge makes sure the result is stored only once it is stable, at the end of the cycle.
3. **How is `$zero` implemented?** The read logic returns 0 for address 0, and the write logic ignores address 0.
4. **What is sign extension? Give an example.** 16-bit −5 = 0xFFFB becomes 32-bit 0xFFFFFFFB. The upper bits copy the sign bit.
5. **Why does `andi` use zero extension?** `andi $t0, $t1, 0xFF00` should keep bits 15:8 and clear all others. Sign extension would turn 0xFF00 into 0xFFFFFF00 and keep the upper bits too.
6. **Which register does `jal` write?** `$ra` ($31), through the RegDst multiplexer.
