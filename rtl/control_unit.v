// ============================================================================
// control_unit.v - Main Control Unit
// Owner : Kunal Dev Sahu
//
// Decodes the opcode (and funct, only to recognise jr) and produces every
// control signal that steers the single-cycle datapath.
//
//  reg_dst   : 00 = rt, 01 = rd, 10 = $31 (jal)
//  mem_to_reg: 00 = ALU result, 01 = memory data, 10 = PC+4 (jal)
// ============================================================================
`include "defines.vh"

module control_unit (
    input  wire [5:0] opcode,
    input  wire [5:0] funct,
    output reg  [1:0] reg_dst,
    output reg        alu_src,      // 0 = rt, 1 = immediate
    output reg  [1:0] mem_to_reg,
    output reg        reg_write,
    output reg        mem_read,
    output reg        mem_write,
    output reg        mem_byte,     // byte access (lb, lbu, sb)
    output reg        mem_unsigned, // lbu
    output reg        branch,       // beq
    output reg        branch_ne,    // bne
    output reg        jump,         // j, jal
    output reg        jump_reg,     // jr
    output reg        ext_op,       // 1 = sign-extend, 0 = zero-extend
    output reg  [2:0] alu_op
);
    always @(*) begin
        // ---- safe defaults: do nothing ----
        reg_dst      = 2'b00;
        alu_src      = 1'b0;
        mem_to_reg   = 2'b00;
        reg_write    = 1'b0;
        mem_read     = 1'b0;
        mem_write    = 1'b0;
        mem_byte     = 1'b0;
        mem_unsigned = 1'b0;
        branch       = 1'b0;
        branch_ne    = 1'b0;
        jump         = 1'b0;
        jump_reg     = 1'b0;
        ext_op       = 1'b1;
        alu_op       = `ALUOP_ADD;

        case (opcode)
            `OP_RTYPE: begin
                if (funct == `FN_JR) begin
                    jump_reg  = 1'b1;
                end else begin
                    reg_dst   = 2'b01;
                    reg_write = 1'b1;
                    alu_op    = `ALUOP_RTYPE;
                end
            end
            `OP_ADDI, `OP_ADDIU: begin
                alu_src = 1'b1; reg_write = 1'b1; alu_op = `ALUOP_ADD;
            end
            `OP_SLTI: begin
                alu_src = 1'b1; reg_write = 1'b1; alu_op = `ALUOP_SLT;
            end
            `OP_ANDI: begin
                alu_src = 1'b1; reg_write = 1'b1; alu_op = `ALUOP_AND; ext_op = 1'b0;
            end
            `OP_ORI: begin
                alu_src = 1'b1; reg_write = 1'b1; alu_op = `ALUOP_OR;  ext_op = 1'b0;
            end
            `OP_XORI: begin
                alu_src = 1'b1; reg_write = 1'b1; alu_op = `ALUOP_XOR; ext_op = 1'b0;
            end
            `OP_LUI: begin
                alu_src = 1'b1; reg_write = 1'b1; alu_op = `ALUOP_LUI;
            end
            `OP_LW: begin
                alu_src = 1'b1; reg_write = 1'b1; mem_read = 1'b1; mem_to_reg = 2'b01;
            end
            `OP_LB: begin
                alu_src = 1'b1; reg_write = 1'b1; mem_read = 1'b1; mem_to_reg = 2'b01;
                mem_byte = 1'b1;
            end
            `OP_LBU: begin
                alu_src = 1'b1; reg_write = 1'b1; mem_read = 1'b1; mem_to_reg = 2'b01;
                mem_byte = 1'b1; mem_unsigned = 1'b1;
            end
            `OP_SW: begin
                alu_src = 1'b1; mem_write = 1'b1;
            end
            `OP_SB: begin
                alu_src = 1'b1; mem_write = 1'b1; mem_byte = 1'b1;
            end
            `OP_BEQ: begin
                branch = 1'b1; alu_op = `ALUOP_SUB;
            end
            `OP_BNE: begin
                branch_ne = 1'b1; alu_op = `ALUOP_SUB;
            end
            `OP_J: begin
                jump = 1'b1;
            end
            `OP_JAL: begin
                jump = 1'b1; reg_write = 1'b1; reg_dst = 2'b10; mem_to_reg = 2'b10;
            end
            default: ; // unknown opcode -> behaves like nop
        endcase
    end
endmodule
