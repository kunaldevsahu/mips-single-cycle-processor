# =============================================================================
# array_sum.asm - Store 1..10 in an array with sw, then add them up
# Owner : Pranav Singh
#
# C equivalent:
#     int a[10];
#     for (i = 0; i < 10; i++) a[i] = i + 1;     // array storage using sw
#     sum = 0;
#     for (i = 0; i < 10; i++) sum += a[i];      // array access using lw
#     print(sum);                                 // 55
# =============================================================================
        .data
arr:    .space 40                  # 10 words

        .text
main:   lui   $s7, 0xFFFF          # I/O base
        la    $s0, arr             # s0 = &a[0]
        li    $s1, 10              # n = 10

        # ---- fill: a[i] = i + 1 ----
        li    $t0, 0               # i = 0
        move  $t1, $s0             # p = &a[0]
fill:   addi  $t2, $t0, 1
        sw    $t2, 0($t1)          # a[i] = i + 1
        addi  $t0, $t0, 1
        addi  $t1, $t1, 4
        bne   $t0, $s1, fill

        # ---- sum ----
        li    $t0, 0               # i = 0
        li    $v0, 0               # sum = 0
        move  $t1, $s0
sum:    lw    $t2, 0($t1)
        add   $v0, $v0, $t2
        addi  $t0, $t0, 1
        addi  $t1, $t1, 4
        blt   $t0, $s1, sum

        sw    $v0, 0($s7)          # OUT 55
        lw    $t3, 36($s0)         # last element
        sw    $t3, 0($s7)          # OUT 10
        sw    $zero, 4($s7)        # HALT
