# =============================================================================
# cache_seq.asm - Cache demo 1: SEQUENTIAL access (good spatial locality)
# Owner : Pranav Singh
#
# Reads 64 consecutive words twice. With 4-word cache blocks only the first
# word of each block misses on the first pass -> 16 misses out of 64 reads.
# The array (256 B) fits exactly in the 256 B cache, so the second pass is
# all hits (temporal locality).  Expected read hit rate = 112 / 128 = 87.5 %
# =============================================================================
        .data
arr:    .space 256                 # 64 words, all zero

        .text
main:   lui   $s7, 0xFFFF
        la    $s0, arr
        li    $s2, 2               # two passes
        li    $v0, 0
pass:   li    $t0, 0
        move  $t1, $s0
loop:   lw    $t2, 0($t1)
        add   $v0, $v0, $t2
        addi  $t2, $t0, 1
        add   $v0, $v0, $t2        # sum also adds the index so output is non-zero
        addi  $t0, $t0, 1
        addi  $t1, $t1, 4
        slti  $t3, $t0, 64
        bnez  $t3, loop
        addi  $s2, $s2, -1
        bnez  $s2, pass
        sw    $v0, 0($s7)          # OUT 2 * (1+2+...+64) = 4160
        sw    $zero, 4($s7)        # HALT
