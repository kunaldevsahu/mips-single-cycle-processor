# =============================================================================
# cache_stride.asm - Cache demo 2: STRIDED access (conflict misses)
# Owner : Pranav Singh
#
# Reads 8 words that are 256 bytes apart, twice. Every address maps to the
# SAME cache line (index bits [7:4] are equal), so each read evicts the
# previous block and every single access misses.  Expected hit rate = 0 %
# Compare with cache_seq.asm to see why locality matters.
# =============================================================================
        .data
arr:    .space 2048

        .text
main:   lui   $s7, 0xFFFF
        la    $s0, arr
        li    $s2, 2               # two passes
        li    $v0, 0
pass:   li    $t0, 0
        move  $t1, $s0
loop:   lw    $t2, 0($t1)
        add   $v0, $v0, $t2
        addi  $v0, $v0, 1          # count the reads
        addi  $t0, $t0, 1
        addi  $t1, $t1, 256        # stride = 256 bytes = one full cache size
        slti  $t3, $t0, 8
        bnez  $t3, loop
        addi  $s2, $s2, -1
        bnez  $s2, pass
        sw    $v0, 0($s7)          # OUT 16 reads
        sw    $zero, 4($s7)        # HALT
