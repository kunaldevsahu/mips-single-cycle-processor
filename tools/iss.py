#!/usr/bin/env python3
"""
iss.py - Instruction Set Simulator (golden reference model)
Owner : Kunal Dev Sahu

Runs a MIPS program in Python, one instruction at a time, using exactly the
same instruction set and memory map as the Verilog processor. Its output is
compared with the hardware simulation: if both agree, the hardware is correct.

Usage:
    python3 tools/iss.py programs/fibonacci.asm            # print OUT values
    python3 tools/iss.py programs/fibonacci.asm --trace    # print every instruction
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from assembler import assemble_file, TEXT_BASE, DATA_BASE, REG_NAMES  # noqa: E402

RAM_SIZE = 4096
IO_OUT, IO_HALT, IO_LED, IO_CYCLE = 0xFFFF0000, 0xFFFF0004, 0xFFFF0008, 0xFFFF000C
M32 = 0xFFFFFFFF


def s32(x):
    x &= M32
    return x - (1 << 32) if x & 0x80000000 else x


def sext16(x):
    x &= 0xFFFF
    return x - 0x10000 if x & 0x8000 else x


class ISS:
    def __init__(self, text_words, data_bytes):
        self.imem = list(text_words)
        self.ram = bytearray(RAM_SIZE)
        self.ram[:len(data_bytes)] = data_bytes
        self.regs = [0] * 32
        self.pc = TEXT_BASE
        self.outputs = []
        self.halted = False
        self.leds = 0
        self.steps = 0
        self.loads = self.stores = 0

    # ---------------- memory ----------------
    def ram_index(self, addr, size):
        off = addr - DATA_BASE
        if not 0 <= off <= RAM_SIZE - size:
            raise RuntimeError(f"address 0x{addr:08x} outside data RAM (pc=0x{self.pc:08x})")
        if size == 4 and addr % 4:
            raise RuntimeError(f"misaligned word access 0x{addr:08x} (pc=0x{self.pc:08x})")
        return off

    def load(self, addr, size, signed):
        self.loads += 1
        if (addr >> 16) == 0xFFFF:
            reg = (addr >> 2) & 0xF
            val = {0: self.outputs[-1] if self.outputs else 0, 1: int(self.halted),
                   2: self.leds, 3: self.steps}.get(reg, 0)
            if size == 1:
                val = (val >> (8 * (addr & 3))) & 0xFF
                if signed and val & 0x80:
                    val |= 0xFFFFFF00
            return val & M32
        i = self.ram_index(addr, size)
        val = int.from_bytes(self.ram[i:i + size], "little")
        if size == 1 and signed and val & 0x80:
            val |= 0xFFFFFF00
        return val

    def store(self, addr, size, val):
        self.stores += 1
        if (addr >> 16) == 0xFFFF:
            reg = (addr >> 2) & 0xF
            if reg == 0:
                self.outputs.append(val & M32)
            elif reg == 1:
                self.halted = True
            elif reg == 2:
                self.leds = val & 0xFF
            return
        i = self.ram_index(addr, size)
        self.ram[i:i + size] = (val & ((1 << (8 * size)) - 1)).to_bytes(size, "little")

    # ---------------- execute one instruction ----------------
    def step(self, trace=False):
        idx = (self.pc - TEXT_BASE) >> 2
        ins = self.imem[idx] if 0 <= idx < len(self.imem) else 0
        op, rs, rt, rd = ins >> 26, (ins >> 21) & 31, (ins >> 16) & 31, (ins >> 11) & 31
        sh, fn, imm = (ins >> 6) & 31, ins & 63, ins & 0xFFFF
        R = self.regs
        a, b = R[rs], R[rt]
        npc = (self.pc + 4) & M32
        wr = None   # (reg, value)

        if op == 0:
            if fn == 0x08:
                npc = a
            else:
                v = {0x20: a + b, 0x21: a + b, 0x22: a - b, 0x23: a - b, 0x24: a & b,
                     0x25: a | b, 0x26: a ^ b, 0x27: ~(a | b), 0x2A: int(s32(a) < s32(b)),
                     0x00: b << sh, 0x02: b >> sh, 0x03: s32(b) >> sh}.get(fn, 0)
                wr = (rd, v)
        elif op in (0x08, 0x09):
            wr = (rt, a + sext16(imm))
        elif op == 0x0A:
            wr = (rt, int(s32(a) < sext16(imm)))
        elif op == 0x0C:
            wr = (rt, a & imm)
        elif op == 0x0D:
            wr = (rt, a | imm)
        elif op == 0x0E:
            wr = (rt, a ^ imm)
        elif op == 0x0F:
            wr = (rt, imm << 16)
        elif op in (0x20, 0x23, 0x24):
            addr = (a + sext16(imm)) & M32
            size = 4 if op == 0x23 else 1
            wr = (rt, self.load(addr, size, op == 0x20))
        elif op in (0x28, 0x2B):
            addr = (a + sext16(imm)) & M32
            self.store(addr, 4 if op == 0x2B else 1, b)
        elif op == 0x04 and a == b:
            npc = (self.pc + 4 + (sext16(imm) << 2)) & M32
        elif op == 0x05 and a != b:
            npc = (self.pc + 4 + (sext16(imm) << 2)) & M32
        elif op == 0x02:
            npc = ((self.pc + 4) & 0xF0000000) | ((ins & 0x3FFFFFF) << 2)
        elif op == 0x03:
            wr = (31, self.pc + 4)
            npc = ((self.pc + 4) & 0xF0000000) | ((ins & 0x3FFFFFF) << 2)

        if trace:
            print(f"0x{self.pc:08x}: {ins:08x}" + (f"   ${REG_NAMES[wr[0]]} = 0x{wr[1] & M32:08x}"
                                                 if wr and wr[0] else ""))
        if wr and wr[0] != 0:
            R[wr[0]] = wr[1] & M32
        self.pc = npc
        self.steps += 1


def run(path, max_steps=200000, trace=False):
    asm = assemble_file(path)
    sim = ISS([w for _, w, _ in asm.text], bytes(asm.data))
    while not sim.halted:
        if sim.steps >= max_steps:
            raise RuntimeError("program did not halt (step limit reached)")
        sim.step(trace)
    return sim


def main():
    ap = argparse.ArgumentParser(description="MIPS instruction-set simulator (golden model)")
    ap.add_argument("source")
    ap.add_argument("--trace", action="store_true")
    ap.add_argument("--max-steps", type=int, default=200000)
    ap.add_argument("--write-expected", metavar="FILE", help="save OUT values as hex")
    args = ap.parse_args()
    sim = run(args.source, args.max_steps, args.trace)
    print(f"{args.source}: {sim.steps} instructions, {len(sim.outputs)} outputs")
    for v in sim.outputs:
        print(f"  OUT 0x{v:08x}  ({s32(v)})")
    if args.write_expected:
        with open(args.write_expected, "w") as f:
            for v in sim.outputs:
                f.write(f"{v:08x}\n")


if __name__ == "__main__":
    main()
