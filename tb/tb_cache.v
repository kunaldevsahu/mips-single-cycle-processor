// ============================================================================
// tb_cache.v - Unit test for cache.v (connected to data_mem.v)
// Owner : Kunal Dev Sahu
// ============================================================================
`timescale 1ns/1ps

module tb_cache;
    reg         clk = 0, rst = 1;
    reg  [31:0] addr = 32'h1001_0000, wdata = 0;
    reg         re = 0, we = 0;
    reg  [3:0]  be = 4'hF;
    wire [31:0] rdata, m_addr, m_wdata, m_rdata;
    wire        m_we;
    wire [3:0]  m_be;
    wire [127:0] m_line;
    wire [31:0] rh, rm, wh, wm;

    cache dut (.clk(clk), .rst(rst), .addr(addr), .re(re), .we(we), .be(be),
               .wdata(wdata), .rdata(rdata), .mem_addr(m_addr), .mem_we(m_we),
               .mem_be(m_be), .mem_wdata(m_wdata), .mem_line(m_line),
               .read_hits(rh), .read_misses(rm), .write_hits(wh), .write_misses(wm));

    data_mem ram (.clk(clk), .addr(m_addr), .we(m_we), .be(m_be), .wdata(m_wdata),
                  .rdata(m_rdata), .line_addr(m_addr), .line_data(m_line));

    always #5 clk = ~clk;
    integer errors = 0, tests = 0, i;

    task expect_eq(input [31:0] got, input [31:0] exp, input [8*24-1:0] what);
        begin
            tests = tests + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("  FAIL %0s: got %0h expected %0h", what, got, exp);
            end
        end
    endtask

    task rd(input [31:0] a, output [31:0] v);
        begin @(negedge clk); addr = a; re = 1; #1 v = rdata; @(negedge clk); re = 0; end
    endtask

    task wr(input [31:0] a, input [31:0] d, input [3:0] b);
        begin @(negedge clk); addr = a; wdata = d; be = b; we = 1; @(negedge clk); we = 0; end
    endtask

    reg [31:0] v;

    initial begin
        $display("== tb_cache ==");
        for (i = 0; i < 64; i = i + 1) ram.mem[i] = 32'h100 + i;
        @(negedge clk); @(negedge clk); rst = 0;

        // first read of a block = miss, next 3 words of the same block = hits
        rd(32'h1001_0000, v); expect_eq(v, 32'h100, "miss data");
        rd(32'h1001_0004, v); expect_eq(v, 32'h101, "hit data 1");
        rd(32'h1001_0008, v); expect_eq(v, 32'h102, "hit data 2");
        rd(32'h1001_000C, v); expect_eq(v, 32'h103, "hit data 3");
        expect_eq(rm, 1, "1 miss");
        expect_eq(rh, 3, "3 hits");

        // write hit updates both cache and RAM (write-through)
        wr(32'h1001_0004, 32'hAAAA_BBBB, 4'hF);
        expect_eq(wh, 1, "write hit counted");
        expect_eq(ram.mem[1], 32'hAAAA_BBBB, "write-through to RAM");
        rd(32'h1001_0004, v); expect_eq(v, 32'hAAAA_BBBB, "cache updated");

        // byte write hit merges correctly
        wr(32'h1001_0004, 32'h0000_CC00, 4'b0010);
        rd(32'h1001_0004, v); expect_eq(v, 32'hAAAA_CCBB, "byte merge");

        // write miss: no allocate, RAM still updated
        wr(32'h1001_0040, 32'h1234_5678, 4'hF);
        expect_eq(wm, 1, "write miss counted");
        expect_eq(ram.mem[16], 32'h1234_5678, "write miss to RAM");

        // conflict: 0x1001_0100 maps to the same line (index 0) as 0x1001_0000
        rd(32'h1001_0100, v); expect_eq(v, 32'h0, "conflict miss data");
        rd(32'h1001_0000, v); expect_eq(v, 32'h100, "evicted -> miss again");
        expect_eq(rm, 3, "3 misses total");

        $display("  stats: read hits=%0d misses=%0d, write hits=%0d misses=%0d", rh, rm, wh, wm);
        if (errors == 0) $display("PASS: tb_cache (%0d tests)", tests);
        else             $display("FAIL: tb_cache (%0d of %0d tests failed)", errors, tests);
        $finish;
    end
endmodule
