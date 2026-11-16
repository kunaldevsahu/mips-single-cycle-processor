// ============================================================================
// tb_reg_file.v - Unit test for reg_file.v
// Owner : Himanshu Pal
// ============================================================================
`timescale 1ns/1ps

module tb_reg_file;
    reg         clk = 0, rst = 1, we = 0;
    reg  [4:0]  ra1 = 0, ra2 = 0, wa = 0;
    reg  [31:0] wd = 0;
    wire [31:0] rd1, rd2;
    integer errors = 0, tests = 0, i;

    reg_file dut (.clk(clk), .rst(rst), .we(we), .ra1(ra1), .ra2(ra2),
                  .wa(wa), .wd(wd), .rd1(rd1), .rd2(rd2));

    always #5 clk = ~clk;

    task write_reg(input [4:0] r, input [31:0] v);
        begin
            @(negedge clk); we = 1; wa = r; wd = v;
            @(negedge clk); we = 0;
        end
    endtask

    task expect_eq(input [31:0] got, input [31:0] exp, input [8*16-1:0] what);
        begin
            tests = tests + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("  FAIL %0s: got %h expected %h", what, got, exp);
            end
        end
    endtask

    initial begin
        $display("== tb_reg_file ==");
        @(negedge clk); @(negedge clk); rst = 0;

        // after reset every register reads 0
        for (i = 0; i < 32; i = i + 1) begin
            ra1 = i; #1; expect_eq(rd1, 0, "reset");
        end

        // write a distinct value to every register 1..31
        for (i = 1; i < 32; i = i + 1) write_reg(i, 32'hA000_0000 + i);

        // read back through BOTH ports
        for (i = 1; i < 32; i = i + 1) begin
            ra1 = i; ra2 = 32 - i; #1;
            expect_eq(rd1, 32'hA000_0000 + i,        "port1");
            expect_eq(rd2, 32'hA000_0000 + (32 - i), "port2");
        end

        // $zero is hard-wired
        write_reg(0, 32'hDEAD_BEEF);
        ra1 = 0; ra2 = 0; #1;
        expect_eq(rd1, 0, "$zero p1");
        expect_eq(rd2, 0, "$zero p2");

        // write enable low -> no change
        @(negedge clk); we = 0; wa = 5; wd = 32'h1234_5678;
        @(negedge clk); ra1 = 5; #1;
        expect_eq(rd1, 32'hA000_0005, "we=0");

        // write happens only on the clock edge (not before)
        @(negedge clk); we = 1; wa = 7; wd = 32'h7777_7777; ra1 = 7; #1;
        expect_eq(rd1, 32'hA000_0007, "before edge");
        @(posedge clk); #1;
        expect_eq(rd1, 32'h7777_7777, "after edge");
        we = 0;

        if (errors == 0) $display("PASS: tb_reg_file (%0d tests)", tests);
        else             $display("FAIL: tb_reg_file (%0d of %0d tests failed)", errors, tests);
        $finish;
    end
endmodule
