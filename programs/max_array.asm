# =============================================================================
# max_array.asm - Find the maximum and minimum element of an array
# Owner : Pranav Singh
#
# C equivalent:
#     int a[] = {12, -7, 45, 3, 99, -150, 67, 0, 23, 8};
#     max = min = a[0];
#     for (i = 1; i < 10; i++) {
#         if (a[i] > max) max = a[i];
#         if (a[i] < min) min = a[i];
#     }
#     print(max); print(min);                 // 99, -150
# =============================================================================
        .data
arr:    .word 12, -7, 45, 3, 99, -150, 67, 0, 23, 8
len:    .word 10

        .text
main:   lui   $s7, 0xFFFF
        la    $s0, arr
        la    $t9, len
        lw    $s1, 0($t9)          # n
        lw    $s2, 0($s0)          # max = a[0]
        move  $s3, $s2             # min = a[0]
        li    $t0, 1               # i = 1

loop:   beq   $t0, $s1, done
        sll   $t1, $t0, 2          # offset = i * 4
        add   $t1, $s0, $t1
        lw    $t2, 0($t1)          # a[i]
        slt   $t3, $s2, $t2        # max < a[i] ?
        beq   $t3, $zero, chkmin
        move  $s2, $t2
chkmin: slt   $t3, $t2, $s3        # a[i] < min ?
        beq   $t3, $zero, next
        move  $s3, $t2
next:   addi  $t0, $t0, 1
        j     loop

done:   sw    $s2, 0($s7)          # OUT max
        sw    $s3, 0($s7)          # OUT min
        sw    $zero, 4($s7)        # HALT
