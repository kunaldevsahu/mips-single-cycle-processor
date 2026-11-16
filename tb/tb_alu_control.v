// ============================================================================
// tb_alu_control.v - Unit test for alu_control.v
// Owner : Vaibhav Singh
// ============================================================================
`timescale 1ns/1ps
`include "defines.vh"

module tb_alu_control;
    reg  [2:0] op;
    reg  [5:0] fn;
    wire [3:0] ctrl;
    integer errors = 0, tests = 0;

    alu_control dut (.alu_op(op), .funct(fn), .alu_ctrl(ctrl));

    task check(input [2:0] o, input [5:0] f, input [3:0] exp);
        begin
            op = o; fn = f; #1;
            tests = tests + 1;
            if (ctrl !== exp) begin
                errors = errors + 1;
                $display("  FAIL alu_op=%b funct=%h -> %b, expected %b", o, f, ctrl, exp);
            end
        end
    endtask

    initial begin
        $display("== tb_alu_control ==");
        // non R-type
        check(`ALUOP_ADD, 6'hxx, `ALU_ADD);
        check(`ALUOP_SUB, 6'hxx, `ALU_SUB);
        check(`ALUOP_AND, 6'hxx, `ALU_AND);
        check(`ALUOP_OR , 6'hxx, `ALU_OR);
        check(`ALUOP_XOR, 6'hxx, `ALU_XOR);
        check(`ALUOP_SLT, 6'hxx, `ALU_SLT);
        check(`ALUOP_LUI, 6'hxx, `ALU_LUI);
        // R-type: decided by funct
        check(`ALUOP_RTYPE, `FN_ADD , `ALU_ADD);
        check(`ALUOP_RTYPE, `FN_ADDU, `ALU_ADD);
        check(`ALUOP_RTYPE, `FN_SUB , `ALU_SUB);
        check(`ALUOP_RTYPE, `FN_SUBU, `ALU_SUB);
        check(`ALUOP_RTYPE, `FN_AND , `ALU_AND);
        check(`ALUOP_RTYPE, `FN_OR  , `ALU_OR);
        check(`ALUOP_RTYPE, `FN_XOR , `ALU_XOR);
        check(`ALUOP_RTYPE, `FN_NOR , `ALU_NOR);
        check(`ALUOP_RTYPE, `FN_SLT , `ALU_SLT);
        check(`ALUOP_RTYPE, `FN_SLL , `ALU_SLL);
        check(`ALUOP_RTYPE, `FN_SRL , `ALU_SRL);
        check(`ALUOP_RTYPE, `FN_SRA , `ALU_SRA);

        if (errors == 0) $display("PASS: tb_alu_control (%0d tests)", tests);
        else             $display("FAIL: tb_alu_control (%0d of %0d tests failed)", errors, tests);
        $finish;
    end
endmodule
