// ============================================================================
// tb_sign_extend.v - Unit test for sign_extend.v
// Owner : Himanshu Pal
// ============================================================================
`timescale 1ns/1ps

module tb_sign_extend;
    reg  [15:0] imm;
    reg         ext_op;
    wire [31:0] y;
    integer errors = 0, tests = 0;

    sign_extend dut (.imm(imm), .ext_op(ext_op), .imm_ext(y));

    task check(input [15:0] i, input e, input [31:0] exp);
        begin
            imm = i; ext_op = e; #1;
            tests = tests + 1;
            if (y !== exp) begin
                errors = errors + 1;
                $display("  FAIL imm=%h ext_op=%b -> %h expected %h", i, e, y, exp);
            end
        end
    endtask

    initial begin
        $display("== tb_sign_extend ==");
        // sign extension
        check(16'h0005, 1, 32'h0000_0005);   //  +5
        check(16'hFFFB, 1, 32'hFFFF_FFFB);   //  -5
        check(16'h7FFF, 1, 32'h0000_7FFF);   //  largest positive
        check(16'h8000, 1, 32'hFFFF_8000);   //  most negative
        check(16'h0000, 1, 32'h0000_0000);
        check(16'hFFFF, 1, 32'hFFFF_FFFF);   //  -1
        // zero extension (andi / ori / xori)
        check(16'hFFFB, 0, 32'h0000_FFFB);
        check(16'h8000, 0, 32'h0000_8000);
        check(16'h1234, 0, 32'h0000_1234);

        if (errors == 0) $display("PASS: tb_sign_extend (%0d tests)", tests);
        else             $display("FAIL: tb_sign_extend (%0d of %0d tests failed)", errors, tests);
        $finish;
    end
endmodule
