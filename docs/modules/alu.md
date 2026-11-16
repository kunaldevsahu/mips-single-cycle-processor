# ALU and ALU Control

**Owner:** Vaibhav Singh ([@VaibhavSingh50](https://github.com/VaibhavSingh50))
**Files:** `rtl/alu.v`, `rtl/alu_control.v`, `tb/tb_alu.v`, `tb/tb_alu_control.v`

## What it does

The **ALU** (Arithmetic Logic Unit) does all the calculation in the processor. Every instruction except `j` uses it:

| Instruction kind | What the ALU computes |
|---|---|
| `add`, `addi`, `sub`, `and`, `or`, ... | the arithmetic / logic result |
| `lw`, `sw`, `lb`, `sb` | the memory address `rs + offset` |
| `beq`, `bne` | `rs − rt`; the **zero** flag says whether they are equal |
| `slt`, `slti` | 1 if `rs < rt` (signed), else 0 |
| `sll`, `srl`, `sra` | shifts by `shamt` |
| `lui` | `imm << 16` |

The **ALU control** chooses which operation the ALU does. It uses *two-level decoding*:
1. The main control unit looks only at the opcode and sends a 3-bit `alu_op` ("add", "subtract", "R-type", "and", ...).
2. If `alu_op` = R-type, the ALU control reads the 6-bit `funct` field to find the exact operation.

This keeps the main control unit small, because all R-type instructions share one opcode (0).

## Interface

### `alu.v`
| Port | Dir | Width | Meaning |
|---|---|---|---|
| `a` | in | 32 | operand A (always `rs`) |
| `b` | in | 32 | operand B (`rt` or the immediate) |
| `shamt` | in | 5 | shift amount |
| `alu_ctrl` | in | 4 | operation code |
| `result` | out | 32 | result |
| `zero` | out | 1 | `result == 0` |
| `overflow` | out | 1 | signed overflow on ADD/SUB |

### `alu_control.v`
| Port | Dir | Width | Meaning |
|---|---|---|---|
| `alu_op` | in | 3 | from main control |
| `funct` | in | 6 | instr[5:0] |
| `alu_ctrl` | out | 4 | to ALU |

## How it works

**One adder for both ADD and SUB.** This is the adder-subtractor from Unit 1. In two's complement, `a − b = a + (~b) + 1`, so:

```verilog
wire do_sub = (alu_ctrl == SUB) || (alu_ctrl == SLT);
wire [31:0] b_in = do_sub ? ~b : b;
wire [31:0] sum  = a + b_in + do_sub;     // carry-in = 1 when subtracting
```

**Overflow.** Overflow happens when the two (effective) operands have the same sign but the result has a different sign. For example, 0x7FFFFFFF + 1 = 0x80000000: two positive numbers giving a negative result.

**Signed SLT.** Taking the sign bit of `a − b` is wrong when the subtraction overflows. Example: −2³¹ − 1 overflows to a positive number. So:
- if `a` and `b` have **different signs**, the negative one is smaller → answer = `a[31]`
- if they have the **same sign**, `a − b` cannot overflow → answer = sign of `a − b`

**Shifts.** `sll`/`srl` use Verilog `<<`/`>>`. For `sra`, `$signed(b) >>> shamt` copies the sign bit into the empty positions.

## Testing

`tb_alu.v` runs 19 checks, including edge cases: wrap-around, overflow in both directions, SLT across the sign boundary, and SRA of a negative number.
`tb_alu_control.v` checks all 19 combinations of `alu_op` and `funct`.

```
python3 run_tests.py --unit
```

## Viva questions

1. **Why does the ALU have a `zero` output?** `beq` and `bne` subtract the two registers, and the zero flag tells the next-PC logic whether they were equal.
2. **How is subtraction done without a separate subtractor?** Invert B and set the carry-in to 1 (two's complement).
3. **Why is SLT not just `sum[31]`?** Because `a − b` can overflow. When the signs differ, the negative number is the smaller one.
4. **Why two levels of control?** All R-type instructions have opcode 0, so the funct field is needed. Splitting the decode keeps the main control simple.
5. **Difference between `srl` and `sra`?** `srl` fills with 0s; `sra` fills with the sign bit, so it keeps negative numbers negative (−8 >> 1 = −4).
6. **What does the ALU do for `lw`?** It adds the base register and the sign-extended offset to form the address.
