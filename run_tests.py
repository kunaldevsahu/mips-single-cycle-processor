#!/usr/bin/env python3
"""
run_tests.py - One command to build and test the whole project
Owner : Kunal Dev Sahu

    python3 run_tests.py                 # unit tests + every program
    python3 run_tests.py --unit          # only module testbenches
    python3 run_tests.py --programs      # only full-CPU programs
    python3 run_tests.py --run fibonacci # run one program, show its output
    python3 run_tests.py --run fibonacci --wave   # also write build/fibonacci.vcd
    python3 run_tests.py --run fibonacci --trace  # print every instruction

Needs Icarus Verilog (iverilog + vvp) on the PATH and Python 3.
"""
import argparse
import glob
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
RTL = os.path.join(ROOT, "rtl")
TB = os.path.join(ROOT, "tb")
PROGRAMS = os.path.join(ROOT, "programs")
BUILD = os.path.join(ROOT, "build")
TOOLS = os.path.join(ROOT, "tools")

sys.path.insert(0, TOOLS)

UNIT_TESTS = ["tb_alu", "tb_alu_control", "tb_reg_file", "tb_sign_extend",
              "tb_next_pc", "tb_memory", "tb_control_unit", "tb_cache"]


def rtl_files():
    return sorted(glob.glob(os.path.join(RTL, "*.v")))


def compile_tb(top, out):
    cmd = ["iverilog", "-g2005", "-I", RTL, "-s", top, "-o", out,
           os.path.join(TB, top + ".v")] + rtl_files()
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stdout + r.stderr)
        return False
    return True


def vvp(out, args=()):
    r = subprocess.run(["vvp", "-n", out] + list(args), capture_output=True, text=True, cwd=ROOT)
    # memories are bigger than the programs, so $readmemh warns "Not enough words": harmless
    return "\n".join(l for l in (r.stdout + r.stderr).splitlines()
                     if "Not enough words" not in l and not l.startswith("VCD info"))


def run_unit():
    print("=" * 60 + "\n UNIT TESTS (one testbench per module)\n" + "=" * 60)
    passed = 0
    for t in UNIT_TESTS:
        if not os.path.exists(os.path.join(TB, t + ".v")):
            print(f"  SKIP  {t:<18} (file not present yet)")
            continue
        out = os.path.join(BUILD, t + ".vvp")
        if not compile_tb(t, out):
            print(f"  FAIL  {t:<18} (compile error)")
            continue
        log = vvp(out)
        m = re.search(r"^(PASS|FAIL): .*$", log, re.M)
        ok = m and m.group(1) == "PASS"
        passed += bool(ok)
        print(f"  {'PASS' if ok else 'FAIL'}  {m.group(0)[6:] if m else t}")
        if not ok:
            print(log)
    return passed, len(UNIT_TESTS)


def assemble(name):
    from assembler import assemble_file
    asm = assemble_file(os.path.join(PROGRAMS, name + ".asm"))
    prefix = os.path.join(BUILD, name)
    with open(prefix + ".hex", "w") as f:
        f.writelines(f"{w:08x}\n" for _, w, _ in asm.text)
    with open(prefix + "_data.hex", "w") as f:
        f.writelines(f"{w:08x}\n" for w in (asm.data_words() or [0]))
    return prefix


def run_program(name, wave=False, trace=False, regs=False, quiet=False):
    prefix = assemble(name)
    out = os.path.join(BUILD, "tb_mips_top.vvp")
    if not os.path.exists(out) and not compile_tb("tb_mips_top", out):
        return False, "compile error"
    args = [f"+PROG={prefix}.hex", f"+DATA={prefix}_data.hex"]
    exp = os.path.join(PROGRAMS, name + ".expected")
    if os.path.exists(exp):
        args.append(f"+EXPECT={exp}")
    if wave:
        args.append(f"+VCD={prefix}.vcd")
    if trace:
        args.append("+TRACE")
    if regs:
        args.append("+REGS")
    log = vvp(out, args)
    if not quiet:
        print(log.strip())
    ok = "RESULT: PASS" in log
    return ok, log


def golden_check(name):
    """Compare the expected file with the Python reference model (tools/iss.py)."""
    from iss import run
    exp = os.path.join(PROGRAMS, name + ".expected")
    if not os.path.exists(exp):
        return None
    sim = run(os.path.join(PROGRAMS, name + ".asm"))
    with open(exp) as f:
        want = [int(x, 16) for x in f.read().split()]
    return sim.outputs == want


def run_programs():
    print("=" * 60 + "\n PROGRAM TESTS (whole CPU running real MIPS programs)\n" + "=" * 60)
    names = sorted(os.path.splitext(os.path.basename(p))[0]
                   for p in glob.glob(os.path.join(PROGRAMS, "*.asm")))
    out = os.path.join(BUILD, "tb_mips_top.vvp")
    if not compile_tb("tb_mips_top", out):
        print("  FAIL  could not compile tb_mips_top")
        return 0, len(names)
    passed = 0
    for n in names:
        ok, log = run_program(n, quiet=True)
        g = golden_check(n)
        cyc = re.search(r"Halted after (\d+) cycles", log)
        hit = re.search(r"Read hit rate = ([\d.]+) %", log)
        info = f"{cyc.group(1) if cyc else '?':>5} cycles"
        if hit:
            info += f", cache hit rate {hit.group(1):>5} %"
        if g is not None:
            info += ", golden model " + ("agrees" if g else "DISAGREES")
            ok = ok and g
        passed += ok
        print(f"  {'PASS' if ok else 'FAIL'}  {n:<14} {info}")
        if not ok:
            print(log)
    return passed, len(names)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--unit", action="store_true", help="only unit tests")
    ap.add_argument("--programs", action="store_true", help="only program tests")
    ap.add_argument("--run", metavar="NAME", help="run one program from programs/")
    ap.add_argument("--wave", action="store_true", help="with --run: dump build/NAME.vcd")
    ap.add_argument("--trace", action="store_true", help="with --run: print every instruction")
    args = ap.parse_args()

    for tool in ("iverilog", "vvp"):
        if not shutil.which(tool):
            sys.exit(f"'{tool}' not found. Install Icarus Verilog (see README.md).")
    os.makedirs(BUILD, exist_ok=True)

    if args.run:
        out = os.path.join(BUILD, "tb_mips_top.vvp")
        if not compile_tb("tb_mips_top", out):
            sys.exit(1)
        ok, _ = run_program(args.run, wave=args.wave, trace=args.trace, regs=True)
        if args.wave:
            print(f"\nWaveform written to build/{args.run}.vcd  ->  gtkwave build/{args.run}.vcd")
        sys.exit(0 if ok else 1)

    total_p = total_n = 0
    if not args.programs:
        p, n = run_unit(); total_p += p; total_n += n
    if not args.unit:
        if not os.path.exists(os.path.join(TB, "tb_mips_top.v")):
            print("\n(program tests need tb/tb_mips_top.v - not present yet)")
        else:
            p, n = run_programs(); total_p += p; total_n += n
    print("=" * 60)
    print(f" {total_p}/{total_n} tests passed")
    print("=" * 60)
    sys.exit(0 if total_p == total_n else 1)


if __name__ == "__main__":
    main()
