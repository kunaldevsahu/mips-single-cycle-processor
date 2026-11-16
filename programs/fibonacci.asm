# =============================================================================
# fibonacci.asm - Functions with jal / jr and a stack in data memory
# Owner : Pranav Singh
#
# Part 1: iterative fib(n) for n = 0..10, called as a function with jal
# Part 2: recursive fib(10) - uses the stack (sw/lw of $ra and arguments)
#
# Expected OUT: 0 1 1 2 3 5 8 13 21 34 55, then 55 (recursive)
# =============================================================================
        .text
main:   lui   $s7, 0xFFFF
        li    $sp, 0x10011000      # stack starts at the top of data RAM

        # ---------- part 1: iterative ----------
        li    $s0, 0               # n
        li    $s1, 11
p1:     move  $a0, $s0
        jal   fib_iter
        sw    $v0, 0($s7)          # OUT fib(n)
        addi  $s0, $s0, 1
        bne   $s0, $s1, p1

        # ---------- part 2: recursive ----------
        li    $a0, 10
        jal   fib_rec
        sw    $v0, 0($s7)          # OUT 55
        sw    $zero, 4($s7)        # HALT

# int fib_iter(int n) { a=0; b=1; while(n--) { t=a+b; a=b; b=t; } return a; }
fib_iter:
        li    $t0, 0               # a
        li    $t1, 1               # b
fi_lp:  beqz  $a0, fi_end
        add   $t2, $t0, $t1
        move  $t0, $t1
        move  $t1, $t2
        addi  $a0, $a0, -1
        j     fi_lp
fi_end: move  $v0, $t0
        jr    $ra

# int fib_rec(int n) { if (n < 2) return n; return fib_rec(n-1) + fib_rec(n-2); }
fib_rec:
        slti  $t0, $a0, 2
        beqz  $t0, fr_rec
        move  $v0, $a0             # base case
        jr    $ra
fr_rec: addi  $sp, $sp, -12        # push ra, n, fib(n-1)
        sw    $ra, 0($sp)
        sw    $a0, 4($sp)
        addi  $a0, $a0, -1
        jal   fib_rec              # fib(n-1)
        sw    $v0, 8($sp)
        lw    $a0, 4($sp)
        addi  $a0, $a0, -2
        jal   fib_rec              # fib(n-2)
        lw    $t1, 8($sp)
        add   $v0, $v0, $t1
        lw    $ra, 0($sp)
        addi  $sp, $sp, 12         # pop
        jr    $ra
