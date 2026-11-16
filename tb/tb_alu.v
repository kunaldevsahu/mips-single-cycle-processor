// ============================================================================
// tb_alu.v - Unit test for alu.v
// Owner : Vaibhav Singh
// ============================================================================
`timescale 1ns/1ps
`include "defines.vh"

module tb_alu;
    reg  [31:0] a, b;
    reg  [4:0]  shamt;
    reg  [3:0]  ctrl;
    wire [31:0] y;
    wire        zero, ovf;
    integer errors = 0, tests = 0;

    alu dut (.a(a), .b(b), .shamt(shamt), .alu_ctrl(ctrl),
             .result(y), .zero(zero), .overflow(ovf));

    task check(input [3:0] c, input [31:0] ia, input [31:0] ib, input [4:0] sh,
               input [31:0] exp, input exp_ovf, input [8*8-1:0] name);
        begin
            ctrl = c; a = ia; b = ib; shamt = sh; #1;
            tests = tests + 1;
            if (y !== exp || ovf !== exp_ovf || zero !== (exp == 0)) begin
                errors = errors + 1;
                $display("  FAIL %0s: a=%h b=%h -> %h (ovf=%b), expected %h (ovf=%b)",
                         name, ia, ib, y, ovf, exp, exp_ovf);
            end
        end
    endtask

    initial begin
        $display("== tb_alu ==");
        check(`ALU_ADD, 32'd5,         32'd7,         0, 32'd12,        0, "ADD");
        check(`ALU_ADD, 32'hFFFFFFFF,  32'd1,         0, 32'd0,         0, "ADD-wrap");
        check(`ALU_ADD, 32'h7FFFFFFF,  32'd1,         0, 32'h80000000,  1, "ADD-ovf");
        check(`ALU_SUB, 32'd10,        32'd3,         0, 32'd7,         0, "SUB");
        check(`ALU_SUB, 32'd3,         32'd10,        0, -32'sd7,       0, "SUB-neg");
        check(`ALU_SUB, 32'h80000000,  32'd1,         0, 32'h7FFFFFFF,  1, "SUB-ovf");
        check(`ALU_SUB, 32'd42,        32'd42,        0, 32'd0,         0, "SUB-zero");
        check(`ALU_AND, 32'hF0F0F0F0,  32'h0FF00FF0,  0, 32'h00F000F0,  0, "AND");
        check(`ALU_OR , 32'hF0F0F0F0,  32'h0F0F0F0F,  0, 32'hFFFFFFFF,  0, "OR");
        check(`ALU_XOR, 32'hFF00FF00,  32'h0F0F0F0F,  0, 32'hF00FF00F,  0, "XOR");
        check(`ALU_NOR, 32'hF0F0F0F0,  32'h0F0F0000,  0, 32'h00000F0F,  0, "NOR");
        check(`ALU_SLT, -32'sd5,       32'd3,         0, 32'd1,         0, "SLT-neg");
        check(`ALU_SLT, 32'd3,         -32'sd5,       0, 32'd0,         0, "SLT-pos");
        check(`ALU_SLT, 32'h80000000,  32'h7FFFFFFF,  0, 32'd1,         0, "SLT-ext");
        check(`ALU_SLT, 32'd7,         32'd7,         0, 32'd0,         0, "SLT-eq");
        check(`ALU_SLL, 32'd0,         32'h00000001,  5'd4,  32'h10,       0, "SLL");
        check(`ALU_SRL, 32'd0,         32'h80000000,  5'd31, 32'h1,        0, "SRL");
        check(`ALU_SRA, 32'd0,         32'h80000000,  5'd4,  32'hF8000000, 0, "SRA");
        check(`ALU_LUI, 32'd0,         32'h00001234,  0, 32'h12340000,  0, "LUI");

        if (errors == 0) $display("PASS: tb_alu (%0d tests)", tests);
        else             $display("FAIL: tb_alu (%0d of %0d tests failed)", errors, tests);
        $finish;
    end
endmodule
