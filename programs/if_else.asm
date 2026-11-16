# =============================================================================
# if_else.asm - Conditional statements: absolute value and sign classification
# Owner : Pranav Singh
#
# C equivalent:
#     int a[] = {-5, 0, 7, -12, 3};
#     neg = 0;
#     for (i = 0; i < 5; i++) {
#         if (a[i] < 0) { print(-a[i]); neg++; }   // if
#         else            print(a[i]);              // else
#     }
#     if (neg > 1) print(1); else print(0);         // more than one negative?
#     print(neg);
# Expected OUT: 5, 0, 7, 12, 3, 1, 2
# =============================================================================
        .data
arr:    .word -5, 0, 7, -12, 3

        .text
main:   lui   $s7, 0xFFFF
        la    $s0, arr
        li    $s1, 5               # n
        li    $s2, 0               # neg = 0
        li    $t0, 0               # i

loop:   lw    $t1, 0($s0)
        slt   $t2, $t1, $zero      # a[i] < 0 ?
        beq   $t2, $zero, else1
        sub   $t1, $zero, $t1      # then: t1 = -a[i]
        addi  $s2, $s2, 1          #       neg++
        j     endif1
else1:  nop                        # else: keep a[i]
endif1: sw    $t1, 0($s7)          # OUT |a[i]|
        addi  $s0, $s0, 4
        addi  $t0, $t0, 1
        bne   $t0, $s1, loop

        li    $t3, 1
        bgt   $s2, $t3, many       # if (neg > 1)
        sw    $zero, 0($s7)        #   else  -> OUT 0
        j     fin
many:   sw    $t3, 0($s7)          #   then  -> OUT 1
fin:    sw    $s2, 0($s7)          # OUT neg
        sw    $zero, 4($s7)        # HALT
