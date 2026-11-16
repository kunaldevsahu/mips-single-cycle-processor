# =============================================================================
# instr_test.asm - Exercises EVERY supported instruction once
# Owner : Pranav Singh
#
# Each result is written to the OUT port (0xFFFF0000). The testbench compares
# the sequence of OUT values with programs/instr_test.expected.
# =============================================================================
        .text
main:   lui   $s7, 0xFFFF          # $s7 = 0xFFFF0000  (I/O base address)

        # ---------- I-type arithmetic / logic ----------
        addi  $t0, $zero, 25       # t0 = 25
        addi  $t1, $zero, -7       # t1 = -7
        sw    $t0, 0($s7)          # OUT 25
        sw    $t1, 0($s7)          # OUT -7
        addiu $t2, $t0, 100        # 125
        sw    $t2, 0($s7)
        andi  $t3, $t1, 0x00FF     # 0xF9  (zero-extended immediate)
        sw    $t3, 0($s7)
        ori   $t3, $zero, 0xABCD   # 0x0000ABCD
        sw    $t3, 0($s7)
        xori  $t3, $t3, 0xFFFF     # 0x00005432
        sw    $t3, 0($s7)
        slti  $t4, $t1, 0          # -7 < 0  -> 1
        sw    $t4, 0($s7)
        slti  $t4, $t0, 10         # 25 < 10 -> 0
        sw    $t4, 0($s7)
        lui   $t5, 0x1234          # 0x12340000
        ori   $t5, $t5, 0x5678     # 0x12345678
        sw    $t5, 0($s7)

        # ---------- R-type ----------
        add   $t6, $t0, $t1        # 18
        sw    $t6, 0($s7)
        addu  $t6, $t0, $t0        # 50
        sw    $t6, 0($s7)
        sub   $t6, $t1, $t0        # -32
        sw    $t6, 0($s7)
        subu  $t6, $t0, $t1        # 32
        sw    $t6, 0($s7)
        and   $t6, $t5, $t1        # 0x12345678 & 0xFFFFFFF9 = 0x12345678
        sw    $t6, 0($s7)
        or    $t6, $t0, $t1        # 25 | -7 = -7 (0xFFFFFFF9)
        sw    $t6, 0($s7)
        xor   $t6, $t0, $t1        # 0x19 ^ 0xFFFFFFF9 = 0xFFFFFFE0
        sw    $t6, 0($s7)
        nor   $t6, $t0, $zero      # ~25 = 0xFFFFFFE6
        sw    $t6, 0($s7)
        slt   $t6, $t1, $t0        # -7 < 25 -> 1
        sw    $t6, 0($s7)
        slt   $t6, $t0, $t1        # 25 < -7 -> 0
        sw    $t6, 0($s7)
        sll   $t6, $t0, 4          # 400
        sw    $t6, 0($s7)
        srl   $t6, $t1, 28         # 0xF
        sw    $t6, 0($s7)
        sra   $t6, $t1, 1          # -4
        sw    $t6, 0($s7)

        # ---------- memory ----------
        lui   $s0, 0x1001          # s0 = 0x10010000 (data RAM)
        sw    $t5, 0($s0)          # mem[0] = 0x12345678
        lw    $t7, 0($s0)
        sw    $t7, 0($s7)          # OUT 0x12345678
        lb    $t7, 3($s0)          # byte 3 = 0x12
        sw    $t7, 0($s7)
        addi  $t8, $zero, -100     # 0x9C
        sb    $t8, 1($s0)          # mem[0] = 0x12349C78
        lw    $t7, 0($s0)
        sw    $t7, 0($s7)
        lb    $t7, 1($s0)          # sign-extended -> -100
        sw    $t7, 0($s7)
        lbu   $t7, 1($s0)          # zero-extended -> 156
        sw    $t7, 0($s7)

        # ---------- branches ----------
        addi  $t0, $zero, 5
        addi  $t1, $zero, 5
        beq   $t0, $t1, beq_ok
        sw    $zero, 0($s7)        # skipped
beq_ok: addi  $t9, $zero, 111
        sw    $t9, 0($s7)          # OUT 111
        bne   $t0, $t1, bad        # not taken
        addi  $t1, $zero, 6
        bne   $t0, $t1, bne_ok     # taken
bad:    sw    $zero, 0($s7)
bne_ok: addi  $t9, $zero, 222
        sw    $t9, 0($s7)          # OUT 222

        # ---------- jumps ----------
        j     jmp_ok
        sw    $zero, 0($s7)        # skipped
jmp_ok: jal   func                 # call
        sw    $v0, 0($s7)          # OUT 333 (returned value)
        sw    $zero, 4($s7)        # HALT

func:   addi  $v0, $zero, 333
        jr    $ra
