# =============================================================================
# bubble_sort.asm - Sort an array in memory (nested loops, lw/sw heavy)
# Owner : Pranav Singh
#
# C equivalent:
#     int a[] = {64, 34, 25, 12, 22, 11, 90, 5, -3, 47};
#     for (i = 0; i < n-1; i++)
#         for (j = 0; j < n-1-i; j++)
#             if (a[j] > a[j+1]) swap(a[j], a[j+1]);
#     for (i = 0; i < n; i++) print(a[i]);
# Expected OUT: -3 5 11 12 22 25 34 47 64 90
# =============================================================================
        .data
arr:    .word 64, 34, 25, 12, 22, 11, 90, 5, -3, 47

        .text
main:   lui   $s7, 0xFFFF
        la    $s0, arr
        li    $s1, 10              # n
        addi  $s2, $s1, -1         # n - 1
        li    $t0, 0               # i

outer:  beq   $t0, $s2, print
        sub   $t5, $s2, $t0        # limit = n-1-i
        li    $t1, 0               # j
        move  $t6, $s0             # p = &a[0]
inner:  beq   $t1, $t5, next_i
        lw    $t2, 0($t6)          # a[j]
        lw    $t3, 4($t6)          # a[j+1]
        ble   $t2, $t3, noswap
        sw    $t3, 0($t6)          # swap
        sw    $t2, 4($t6)
noswap: addi  $t1, $t1, 1
        addi  $t6, $t6, 4
        j     inner
next_i: addi  $t0, $t0, 1
        j     outer

print:  li    $t0, 0
        move  $t6, $s0
pr_lp:  lw    $t2, 0($t6)
        sw    $t2, 0($s7)          # OUT a[i]
        addi  $t6, $t6, 4
        addi  $t0, $t0, 1
        bne   $t0, $s1, pr_lp
        sw    $zero, 4($s7)        # HALT
