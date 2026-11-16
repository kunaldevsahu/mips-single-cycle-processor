// ============================================================================
// sign_extend.v - 16-bit to 32-bit Immediate Extender
// Owner : Himanshu Pal
//
// ext_op = 1 : sign extension  (copy bit 15 into the upper 16 bits)
//              used by addi, slti, lw, sw, lb, sb, beq, bne
// ext_op = 0 : zero extension  (fill upper 16 bits with 0)
//              used by the logical immediates andi, ori, xori
// ============================================================================
module sign_extend (
    input  wire [15:0] imm,     // instr[15:0]
    input  wire        ext_op,  // 1 = sign-extend, 0 = zero-extend
    output wire [31:0] imm_ext
);
    assign imm_ext = ext_op ? {{16{imm[15]}}, imm} : {16'b0, imm};
endmodule
