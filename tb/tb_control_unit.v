// ============================================================================
// tb_control_unit.v - Unit test for control_unit.v
// Owner : Kunal Dev Sahu
//
// Checks every opcode against the control-signal table in docs/ARCHITECTURE.md
// Signal vector order:
//   reg_dst(2) alu_src mem_to_reg(2) reg_write mem_read mem_write mem_byte
//   mem_unsigned branch branch_ne jump jump_reg ext_op alu_op(3)   = 18 bits
// ============================================================================
`timescale 1ns/1ps
`include "defines.vh"

module tb_control_unit;
    reg  [5:0] op, fn;
    wire [1:0] reg_dst, mem_to_reg;
    wire [2:0] alu_op;
    wire alu_src, reg_write, mem_read, mem_write, mem_byte, mem_unsigned;
    wire branch, branch_ne, jump, jump_reg, ext_op;

    control_unit dut (.opcode(op), .funct(fn), .reg_dst(reg_dst), .alu_src(alu_src),
        .mem_to_reg(mem_to_reg), .reg_write(reg_write), .mem_read(mem_read),
        .mem_write(mem_write), .mem_byte(mem_byte), .mem_unsigned(mem_unsigned),
        .branch(branch), .branch_ne(branch_ne), .jump(jump), .jump_reg(jump_reg),
        .ext_op(ext_op), .alu_op(alu_op));

    wire [17:0] sig = {reg_dst, alu_src, mem_to_reg, reg_write, mem_read, mem_write,
                       mem_byte, mem_unsigned, branch, branch_ne, jump, jump_reg,
                       ext_op, alu_op};
    integer errors = 0, tests = 0;

    task check(input [5:0] o, input [5:0] f, input [17:0] exp, input [8*6-1:0] name);
        begin
            op = o; fn = f; #1;
            tests = tests + 1;
            if (sig !== exp) begin
                errors = errors + 1;
                $display("  FAIL %0s: got %b expected %b", name, sig, exp);
            end
        end
    endtask

    initial begin
        $display("== tb_control_unit ==");
        //                       rd as mr w r w b u br bn j jr e  aluop
        check(`OP_RTYPE, `FN_ADD, 18'b01_0_00_1_0_0_0_0_0_0_0_0_1_010, "R-type");
        check(`OP_RTYPE, `FN_JR , 18'b00_0_00_0_0_0_0_0_0_0_0_1_1_000, "jr");
        check(`OP_ADDI , 6'h0,    18'b00_1_00_1_0_0_0_0_0_0_0_0_1_000, "addi");
        check(`OP_SLTI , 6'h0,    18'b00_1_00_1_0_0_0_0_0_0_0_0_1_110, "slti");
        check(`OP_ANDI , 6'h0,    18'b00_1_00_1_0_0_0_0_0_0_0_0_0_011, "andi");
        check(`OP_ORI  , 6'h0,    18'b00_1_00_1_0_0_0_0_0_0_0_0_0_100, "ori");
        check(`OP_XORI , 6'h0,    18'b00_1_00_1_0_0_0_0_0_0_0_0_0_101, "xori");
        check(`OP_LUI  , 6'h0,    18'b00_1_00_1_0_0_0_0_0_0_0_0_1_111, "lui");
        check(`OP_LW   , 6'h0,    18'b00_1_01_1_1_0_0_0_0_0_0_0_1_000, "lw");
        check(`OP_LB   , 6'h0,    18'b00_1_01_1_1_0_1_0_0_0_0_0_1_000, "lb");
        check(`OP_LBU  , 6'h0,    18'b00_1_01_1_1_0_1_1_0_0_0_0_1_000, "lbu");
        check(`OP_SW   , 6'h0,    18'b00_1_00_0_0_1_0_0_0_0_0_0_1_000, "sw");
        check(`OP_SB   , 6'h0,    18'b00_1_00_0_0_1_1_0_0_0_0_0_1_000, "sb");
        check(`OP_BEQ  , 6'h0,    18'b00_0_00_0_0_0_0_0_1_0_0_0_1_001, "beq");
        check(`OP_BNE  , 6'h0,    18'b00_0_00_0_0_0_0_0_0_1_0_0_1_001, "bne");
        check(`OP_J    , 6'h0,    18'b00_0_00_0_0_0_0_0_0_0_1_0_1_000, "j");
        check(`OP_JAL  , 6'h0,    18'b10_0_10_1_0_0_0_0_0_0_1_0_1_000, "jal");
        check(6'h3F    , 6'h0,    18'b00_0_00_0_0_0_0_0_0_0_0_0_1_000, "bad-op");

        if (errors == 0) $display("PASS: tb_control_unit (%0d tests)", tests);
        else             $display("FAIL: tb_control_unit (%0d of %0d tests failed)", errors, tests);
        $finish;
    end
endmodule
