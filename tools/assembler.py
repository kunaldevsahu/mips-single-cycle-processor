#!/usr/bin/env python3
"""
assembler.py - Two-pass MIPS assembler for the Single-Cycle MIPS Processor
Owner : Kunal Dev Sahu

Turns a MARS-style .asm file into hex files that the Verilog memories load:
    <out>.hex       instruction words  (text segment, base 0x00400000)
    <out>_data.hex  data words         (data segment, base 0x10010000)
    <out>.lst       listing: address, machine code and source line

Usage:
    python3 tools/assembler.py programs/fibonacci.asm -o build/fibonacci

Supported
    Instructions : add addu sub subu and or xor nor slt sll srl sra jr
                   addi addiu slti andi ori xori lui lw lb lbu sw sb beq bne j jal
    Pseudo-ops   : li la move nop b beqz bnez blt bgt ble bge
    Directives   : .text .data .word .byte .half .asciiz .ascii .space .align .globl
"""
import argparse
import re
import sys

TEXT_BASE = 0x00400000
DATA_BASE = 0x10010000

REG_NAMES = ["zero", "at", "v0", "v1", "a0", "a1", "a2", "a3",
             "t0", "t1", "t2", "t3", "t4", "t5", "t6", "t7",
             "s0", "s1", "s2", "s3", "s4", "s5", "s6", "s7",
             "t8", "t9", "k0", "k1", "gp", "sp", "fp", "ra"]
REGS = {name: i for i, name in enumerate(REG_NAMES)}
REGS.update({str(i): i for i in range(32)})
REGS["s8"] = 30

R_TYPE = {  # name: funct
    "add": 0x20, "addu": 0x21, "sub": 0x22, "subu": 0x23, "and": 0x24,
    "or": 0x25, "xor": 0x26, "nor": 0x27, "slt": 0x2A,
}
SHIFTS = {"sll": 0x00, "srl": 0x02, "sra": 0x03}
I_ARITH = {"addi": 0x08, "addiu": 0x09, "slti": 0x0A, "andi": 0x0C, "ori": 0x0D, "xori": 0x0E}
MEM_OPS = {"lb": 0x20, "lw": 0x23, "lbu": 0x24, "sb": 0x28, "sw": 0x2B}
BRANCH = {"beq": 0x04, "bne": 0x05}
JUMPS = {"j": 0x02, "jal": 0x03}


class AsmError(Exception):
    pass


def parse_reg(tok):
    tok = tok.strip()
    if not tok.startswith("$") or tok[1:] not in REGS:
        raise AsmError(f"bad register '{tok}'")
    return REGS[tok[1:]]


def parse_int(tok):
    tok = tok.strip()
    if len(tok) == 3 and tok[0] == tok[2] == "'":
        return ord(tok[1])
    try:
        return int(tok, 0)
    except ValueError:
        raise AsmError(f"bad number '{tok}'")


def is_int(tok):
    try:
        parse_int(tok)
        return True
    except AsmError:
        return False


def split_operands(s):
    return [p.strip() for p in s.split(",")] if s.strip() else []


def strip_comment(line):
    out, in_str = [], False
    for ch in line:
        if ch == '"':
            in_str = not in_str
        if ch == "#" and not in_str:
            break
        out.append(ch)
    return "".join(out).strip()


def unescape(s):
    return s.encode("utf-8").decode("unicode_escape")


class Assembler:
    def __init__(self):
        self.labels = {}
        self.text = []      # list of (addr, word, src)
        self.data = bytearray()

    # ---------------- pass 1 helpers ----------------
    def pseudo_size(self, op, ops):
        if op == "li":
            v = parse_int(ops[1]) & 0xFFFFFFFF
            sv = v - (1 << 32) if v & 0x80000000 else v
            return 1 if (-32768 <= sv <= 32767 or v <= 0xFFFF) else 2
        if op == "la":
            return 2
        if op in ("blt", "bgt", "ble", "bge"):
            return 2
        return 1

    # ---------------- encoding ----------------
    @staticmethod
    def r(rs, rt, rd, sh, fn):
        return (rs << 21) | (rt << 16) | (rd << 11) | (sh << 6) | fn

    @staticmethod
    def i(op, rs, rt, imm):
        return (op << 26) | (rs << 21) | (rt << 16) | (imm & 0xFFFF)

    def label_addr(self, tok):
        tok = tok.strip()
        if tok in self.labels:
            return self.labels[tok]
        if is_int(tok):
            return parse_int(tok)
        raise AsmError(f"unknown label '{tok}'")

    def branch_off(self, target, pc):
        off = (target - (pc + 4)) >> 2
        if not -32768 <= off <= 32767:
            raise AsmError("branch target too far")
        return off

    def encode(self, op, ops, pc):
        """Return a list of machine words for one source instruction."""
        if op in R_TYPE:
            rd, rs, rt = (parse_reg(x) for x in ops)
            return [self.r(rs, rt, rd, 0, R_TYPE[op])]
        if op in SHIFTS:
            rd, rt = parse_reg(ops[0]), parse_reg(ops[1])
            sh = parse_int(ops[2])
            if not 0 <= sh <= 31:
                raise AsmError("shift amount must be 0..31")
            return [self.r(0, rt, rd, sh, SHIFTS[op])]
        if op == "jr":
            return [self.r(parse_reg(ops[0]), 0, 0, 0, 0x08)]
        if op in I_ARITH:
            rt, rs, imm = parse_reg(ops[0]), parse_reg(ops[1]), parse_int(ops[2])
            if op in ("andi", "ori", "xori"):
                if not 0 <= imm <= 0xFFFF:
                    raise AsmError(f"{op} immediate must be 0..65535")
            elif not -32768 <= imm <= 32767:
                raise AsmError(f"{op} immediate must be -32768..32767")
            return [self.i(I_ARITH[op], rs, rt, imm)]
        if op == "lui":
            imm = parse_int(ops[1])
            if not 0 <= imm <= 0xFFFF:
                raise AsmError("lui immediate must be 0..65535")
            return [self.i(0x0F, 0, parse_reg(ops[0]), imm)]
        if op in MEM_OPS:
            rt = parse_reg(ops[0])
            m = re.fullmatch(r"(.*)\(\s*(\$\w+)\s*\)", ops[1].strip())
            if not m:
                raise AsmError(f"expected offset($reg), got '{ops[1]}'")
            off = parse_int(m.group(1)) if m.group(1).strip() else 0
            if not -32768 <= off <= 32767:
                raise AsmError("memory offset out of range")
            return [self.i(MEM_OPS[op], parse_reg(m.group(2)), rt, off)]
        if op in BRANCH:
            rs, rt = parse_reg(ops[0]), parse_reg(ops[1])
            return [self.i(BRANCH[op], rs, rt, self.branch_off(self.label_addr(ops[2]), pc))]
        if op in JUMPS:
            return [(JUMPS[op] << 26) | ((self.label_addr(ops[0]) >> 2) & 0x3FFFFFF)]

        # ---------------- pseudo instructions ----------------
        if op == "nop":
            return [0]
        if op == "move":
            return [self.r(parse_reg(ops[1]), 0, parse_reg(ops[0]), 0, 0x21)]
        if op == "li":
            rt = parse_reg(ops[0])
            v = parse_int(ops[1]) & 0xFFFFFFFF
            sv = v - (1 << 32) if v & 0x80000000 else v
            if -32768 <= sv <= 32767:
                return [self.i(0x09, 0, rt, sv)]
            if v <= 0xFFFF:
                return [self.i(0x0D, 0, rt, v)]
            return [self.i(0x0F, 0, 1, v >> 16), self.i(0x0D, 1, rt, v & 0xFFFF)]
        if op == "la":
            rt, a = parse_reg(ops[0]), self.label_addr(ops[1])
            return [self.i(0x0F, 0, 1, a >> 16), self.i(0x0D, 1, rt, a & 0xFFFF)]
        if op == "b":
            return [self.i(0x04, 0, 0, self.branch_off(self.label_addr(ops[0]), pc))]
        if op in ("beqz", "bnez"):
            rs = parse_reg(ops[0])
            code = 0x04 if op == "beqz" else 0x05
            return [self.i(code, rs, 0, self.branch_off(self.label_addr(ops[1]), pc))]
        if op in ("blt", "bgt", "ble", "bge"):
            a, b = parse_reg(ops[0]), parse_reg(ops[1])
            target = self.label_addr(ops[2])
            # blt a,b : slt $at,a,b ; bne $at,$0     bge a,b : slt $at,a,b ; beq $at,$0
            # bgt a,b : slt $at,b,a ; bne $at,$0     ble a,b : slt $at,b,a ; beq $at,$0
            x, y = (a, b) if op in ("blt", "bge") else (b, a)
            br = 0x05 if op in ("blt", "bgt") else 0x04
            return [self.r(x, y, 1, 0, 0x2A),
                    self.i(br, 1, 0, self.branch_off(target, pc + 4))]
        raise AsmError(f"unknown instruction '{op}'")

    # ---------------- driver ----------------
    def assemble(self, source):
        lines = source.splitlines()
        # pass 1: labels and sizes
        items = []          # (segment, addr, op, ops, lineno, src)
        seg, tpc, dpc = "text", TEXT_BASE, DATA_BASE
        data_items = []
        for n, raw in enumerate(lines, 1):
            line = strip_comment(raw)
            try:
                names = []
                while True:
                    m = re.match(r"^([A-Za-z_.$][\w.$]*)\s*:\s*(.*)$", line)
                    if not m:
                        break
                    names.append(m.group(1))
                    line = m.group(2)
                parts = line.split(None, 1) if line else [""]
                op = parts[0].lower()
                rest = parts[1] if len(parts) > 1 else ""
                # .word / .half are auto-aligned (like MARS) BEFORE labels are placed
                if seg == "data" and op in (".word", ".half"):
                    a = 4 if op == ".word" else 2
                    pad = (-(dpc - DATA_BASE)) % a
                    if pad:
                        data_items.append((n, ".space", str(pad), raw))
                        dpc += pad
                for name in names:
                    if name in self.labels:
                        raise AsmError(f"duplicate label '{name}'")
                    self.labels[name] = tpc if seg == "text" else dpc
                if not op:
                    continue
                if op == ".text":
                    seg = "text"; continue
                if op == ".data":
                    seg = "data"; continue
                if op in (".globl", ".global", ".ent", ".end"):
                    continue
                if op.startswith("."):
                    if seg != "data":
                        raise AsmError(f"directive {op} only allowed in .data")
                    if op == ".align":
                        a = 1 << parse_int(rest)
                        pad = (-(dpc - DATA_BASE)) % a
                        data_items.append((n, ".space", str(pad), raw)); dpc += pad
                        continue
                    size = self.data_size(op, rest)
                    data_items.append((n, op, rest, raw))
                    dpc += size
                    continue
                if seg != "text":
                    raise AsmError("instruction outside .text")
                ops = split_operands(rest)
                items.append((tpc, op, ops, n, raw.strip()))
                tpc += 4 * self.pseudo_size(op, ops)
            except (AsmError, IndexError) as e:
                raise AsmError(f"line {n}: {e} -> {raw.strip()}")

        # pass 2: encode text
        for pc, op, ops, n, src in items:
            try:
                words = self.encode(op, ops, pc)
            except (AsmError, IndexError) as e:
                raise AsmError(f"line {n}: {e} -> {src}")
            for k, w in enumerate(words):
                self.text.append((pc + 4 * k, w & 0xFFFFFFFF, src if k == 0 else "   (cont.)"))

        # pass 2: emit data
        for n, op, rest, raw in data_items:
            try:
                self.emit_data(op, rest)
            except (AsmError, IndexError) as e:
                raise AsmError(f"line {n}: {e} -> {raw.strip()}")

    def data_size(self, op, rest):
        if op == ".word":
            return 4 * len(split_operands(rest))
        if op == ".half":
            return 2 * len(split_operands(rest))
        if op == ".byte":
            return len(split_operands(rest))
        if op == ".space":
            return parse_int(rest)
        if op in (".asciiz", ".ascii"):
            s = unescape(re.search(r'"(.*)"', rest).group(1))
            return len(s) + (1 if op == ".asciiz" else 0)
        raise AsmError(f"unknown directive {op}")

    def emit_data(self, op, rest):
        if op == ".word":
            for t in split_operands(rest):
                v = self.label_addr(t) if not is_int(t) else parse_int(t)
                self.data += (v & 0xFFFFFFFF).to_bytes(4, "little")
        elif op == ".half":
            for t in split_operands(rest):
                self.data += (parse_int(t) & 0xFFFF).to_bytes(2, "little")
        elif op == ".byte":
            for t in split_operands(rest):
                self.data.append(parse_int(t) & 0xFF)
        elif op == ".space":
            self.data += bytes(parse_int(rest))
        elif op in (".asciiz", ".ascii"):
            s = unescape(re.search(r'"(.*)"', rest).group(1))
            self.data += s.encode("latin-1") + (b"\0" if op == ".asciiz" else b"")

    def data_words(self):
        d = self.data + bytes((-len(self.data)) % 4)
        return [int.from_bytes(d[i:i + 4], "little") for i in range(0, len(d), 4)]


def assemble_file(path):
    asm = Assembler()
    with open(path) as f:
        asm.assemble(f.read())
    return asm


def main():
    ap = argparse.ArgumentParser(description="MIPS assembler for the single-cycle CPU")
    ap.add_argument("source")
    ap.add_argument("-o", "--out", required=True, help="output prefix, e.g. build/prog")
    args = ap.parse_args()
    try:
        asm = assemble_file(args.source)
    except AsmError as e:
        print(f"assembler error: {e}", file=sys.stderr)
        sys.exit(1)

    with open(args.out + ".hex", "w") as f:
        for _, w, _ in asm.text:
            f.write(f"{w:08x}\n")
    with open(args.out + "_data.hex", "w") as f:
        for w in asm.data_words() or [0]:
            f.write(f"{w:08x}\n")
    with open(args.out + ".lst", "w") as f:
        f.write("Address     Code        Source\n")
        for a, w, src in asm.text:
            f.write(f"0x{a:08x}  0x{w:08x}  {src}\n")
        f.write("\nLabels:\n")
        for k, v in sorted(asm.labels.items(), key=lambda kv: kv[1]):
            f.write(f"  {k:<20} 0x{v:08x}\n")
    print(f"assembled {args.source}: {len(asm.text)} instructions, {len(asm.data)} data bytes")


if __name__ == "__main__":
    main()
