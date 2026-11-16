// ============================================================================
// tb_next_pc.v - Unit test for pc_reg.v, next_pc.v and mux.v
// Owner : Pranav Singh
// ============================================================================
`timescale 1ns/1ps
`include "defines.vh"

module tb_next_pc;
    // ---------- next_pc ----------
    reg  [31:0] pc, imm_ext, rs_data;
    reg  [25:0] jidx;
    reg         branch, branch_ne, zero, jump, jump_reg;
    wire [31:0] pc4, npc;
    wire        taken;

    next_pc dut (.pc(pc), .imm_ext(imm_ext), .jump_index(jidx), .rs_data(rs_data),
                 .branch(branch), .branch_ne(branch_ne), .zero(zero),
                 .jump(jump), .jump_reg(jump_reg),
                 .pc_plus4(pc4), .next_pc(npc), .branch_taken(taken));

    // ---------- pc_reg ----------
    reg         clk = 0, rst = 1, stall = 0;
    reg  [31:0] d = 0;
    wire [31:0] q;
    pc_reg u_pc (.clk(clk), .rst(rst), .stall(stall), .next_pc(d), .pc(q));
    always #5 clk = ~clk;

    // ---------- muxes ----------
    reg  [1:0]  s3;
    reg         s2;
    wire [31:0] y2, y3;
    mux2 #(32) u_m2 (.d0(32'hAAAA), .d1(32'hBBBB), .sel(s2), .y(y2));
    mux3 #(32) u_m3 (.d0(32'h1), .d1(32'h2), .d2(32'h3), .sel(s3), .y(y3));

    integer errors = 0, tests = 0;

    task expect_eq(input [31:0] got, input [31:0] exp, input [8*20-1:0] what);
        begin
            tests = tests + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("  FAIL %0s: got %h expected %h", what, got, exp);
            end
        end
    endtask

    task set(input b, input bn, input z, input j, input jr);
        begin branch = b; branch_ne = bn; zero = z; jump = j; jump_reg = jr; #1; end
    endtask

    initial begin
        $display("== tb_next_pc ==");
        pc = 32'h0040_0010; imm_ext = 32'd3; rs_data = 32'h0040_0100; jidx = 26'h010_0020;

        set(0,0,0,0,0); expect_eq(npc, 32'h0040_0014, "sequential");
        expect_eq(pc4, 32'h0040_0014, "pc+4");
        set(1,0,1,0,0); expect_eq(npc, 32'h0040_0020, "beq taken");      // 0x14 + 3*4
        set(1,0,0,0,0); expect_eq(npc, 32'h0040_0014, "beq not taken");
        set(0,1,0,0,0); expect_eq(npc, 32'h0040_0020, "bne taken");
        set(0,1,1,0,0); expect_eq(npc, 32'h0040_0014, "bne not taken");
        imm_ext = 32'hFFFF_FFFC;                                          // -4 -> back 4 instrs
        set(1,0,1,0,0); expect_eq(npc, 32'h0040_0004, "beq backward");
        set(0,0,0,1,0); expect_eq(npc, 32'h0040_0080, "j");              // {0, 0x100020<<2}
        set(0,0,0,0,1); expect_eq(npc, 32'h0040_0100, "jr");
        set(1,0,1,1,0); expect_eq(npc, 32'h0040_0080, "jump priority");

        // pc_reg: reset, load, stall
        @(negedge clk); @(negedge clk);
        expect_eq(q, `TEXT_BASE, "pc reset");
        rst = 0; d = 32'h0040_0004;
        @(negedge clk); expect_eq(q, 32'h0040_0004, "pc load");
        stall = 1; d = 32'h0040_0008;
        @(negedge clk); expect_eq(q, 32'h0040_0004, "pc stall");
        stall = 0;
        @(negedge clk); expect_eq(q, 32'h0040_0008, "pc resume");

        // muxes
        s2 = 0; #1 expect_eq(y2, 32'hAAAA, "mux2 sel0");
        s2 = 1; #1 expect_eq(y2, 32'hBBBB, "mux2 sel1");
        s3 = 0; #1 expect_eq(y3, 1, "mux3 sel0");
        s3 = 1; #1 expect_eq(y3, 2, "mux3 sel1");
        s3 = 2; #1 expect_eq(y3, 3, "mux3 sel2");

        if (errors == 0) $display("PASS: tb_next_pc (%0d tests)", tests);
        else             $display("FAIL: tb_next_pc (%0d of %0d tests failed)", errors, tests);
        $finish;
    end
endmodule
