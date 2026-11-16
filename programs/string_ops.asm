# =============================================================================
# string_ops.asm - Byte-level memory access (lb / lbu / sb)
# Owner : Pranav Singh  (tests Kevish's byte-lane memory interface)
#
#   1. strlen("mips processor")                    -> 14
#   2. convert to upper case in place with lbu/sb   -> "MIPS PROCESSOR"
#   3. reverse the string in place                  -> "ROSSECORP SPIM"
#   4. print first word of the string with lw       -> "ROSS" = 0x53534F52
#   5. lb vs lbu of the byte 0xF0                   -> -16 and 240
# =============================================================================
        .data
str:    .asciiz "mips processor"
        .align 2
neg:    .byte 0xF0

        .text
main:   lui   $s7, 0xFFFF
        la    $s0, str

        # ---- 1. strlen ----
        move  $t0, $s0
len_lp: lbu   $t1, 0($t0)
        beqz  $t1, len_end
        addi  $t0, $t0, 1
        j     len_lp
len_end:
        sub   $s1, $t0, $s0        # length
        sw    $s1, 0($s7)          # OUT 14

        # ---- 2. to upper case ----
        move  $t0, $s0
up_lp:  lbu   $t1, 0($t0)
        beqz  $t1, up_end
        slti  $t2, $t1, 'a'        # c < 'a' ?
        bnez  $t2, up_nxt
        slti  $t2, $t1, 123        # c <= 'z' ?
        beqz  $t2, up_nxt
        addi  $t1, $t1, -32        # c - 32
        sb    $t1, 0($t0)
up_nxt: addi  $t0, $t0, 1
        j     up_lp
up_end: lw    $t3, 0($s0)
        sw    $t3, 0($s7)          # OUT "MIPS" = 0x5350494D

        # ---- 3. reverse in place ----
        move  $t0, $s0             # left
        add   $t1, $s0, $s1
        addi  $t1, $t1, -1         # right
rv_lp:  slt   $t2, $t0, $t1
        beqz  $t2, rv_end
        lb    $t3, 0($t0)
        lb    $t4, 0($t1)
        sb    $t4, 0($t0)
        sb    $t3, 0($t1)
        addi  $t0, $t0, 1
        addi  $t1, $t1, -1
        j     rv_lp
rv_end:
        # ---- 4. first and last word ----
        lw    $t3, 0($s0)
        sw    $t3, 0($s7)          # OUT "ROSS"
        lw    $t3, 8($s0)
        sw    $t3, 0($s7)          # OUT "P SP"
        lbu   $t3, 13($s0)
        sw    $t3, 0($s7)          # OUT 'M' = 77

        # ---- 5. signed vs unsigned byte ----
        la    $t0, neg
        lb    $t1, 0($t0)
        sw    $t1, 0($s7)          # OUT -16
        lbu   $t1, 0($t0)
        sw    $t1, 0($s7)          # OUT 240
        sw    $zero, 4($s7)        # HALT
