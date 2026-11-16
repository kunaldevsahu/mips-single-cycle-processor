// ============================================================================
// tb_memory.v - Unit test for the memory interface:
//               mem_controller.v + data_mem.v + mmio.v + instr_mem.v
// Owner : Kevish Sewliya
// ============================================================================
`timescale 1ns/1ps

module tb_memory;
    reg         clk = 0, rst = 1;
    reg  [31:0] addr = 0, wdata = 0;
    reg         re = 0, we = 0, bytemode = 0, uns = 0;
    wire [31:0] rdata;

    wire [31:0] r_addr, r_wdata, r_rdata, io_wdata, io_rdata, out_data;
    wire        r_re, r_we, io_re, io_we, misaligned, bad_addr, out_valid, halted;
    wire [3:0]  r_be, io_reg;
    wire [7:0]  leds;
    wire [127:0] line;

    mem_controller dut (
        .cpu_addr(addr), .cpu_wdata(wdata), .cpu_re(re), .cpu_we(we),
        .cpu_byte(bytemode), .cpu_unsigned(uns), .cpu_rdata(rdata),
        .ram_addr(r_addr), .ram_re(r_re), .ram_we(r_we), .ram_be(r_be),
        .ram_wdata(r_wdata), .ram_rdata(r_rdata),
        .io_reg(io_reg), .io_re(io_re), .io_we(io_we), .io_wdata(io_wdata),
        .io_rdata(io_rdata), .misaligned(misaligned), .bad_addr(bad_addr));

    data_mem ram (.clk(clk), .addr(r_addr), .we(r_we), .be(r_be), .wdata(r_wdata),
                  .rdata(r_rdata), .line_addr(r_addr), .line_data(line));

    mmio io (.clk(clk), .rst(rst), .reg_sel(io_reg), .re(io_re), .we(io_we),
             .wdata(io_wdata), .rdata(io_rdata), .out_valid(out_valid),
             .out_data(out_data), .halted(halted), .leds(leds));

    // instruction memory: just check it reads what was loaded
    wire [31:0] instr;
    reg  [31:0] iaddr = 32'h0040_0000;
    instr_mem imem (.addr(iaddr), .instr(instr));

    always #5 clk = ~clk;
    integer errors = 0, tests = 0;

    task expect_eq(input [31:0] got, input [31:0] exp, input [8*24-1:0] what);
        begin
            tests = tests + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("  FAIL %0s: got %h expected %h", what, got, exp);
            end
        end
    endtask

    task store(input [31:0] a, input [31:0] d, input b);
        begin
            @(negedge clk); addr = a; wdata = d; bytemode = b; we = 1; re = 0;
            @(negedge clk); we = 0;
        end
    endtask

    task load(input [31:0] a, input b, input u, output [31:0] v);
        begin
            @(negedge clk); addr = a; bytemode = b; uns = u; re = 1; we = 0; #1;
            v = rdata; re = 0;
        end
    endtask

    reg [31:0] v;

    initial begin
        $display("== tb_memory ==");
        @(negedge clk); @(negedge clk); rst = 0;

        // ---- word store / load ----
        store(32'h1001_0000, 32'h1122_3344, 0);
        load (32'h1001_0000, 0, 0, v); expect_eq(v, 32'h1122_3344, "lw after sw");
        store(32'h1001_0FFC, 32'hCAFE_F00D, 0);
        load (32'h1001_0FFC, 0, 0, v); expect_eq(v, 32'hCAFE_F00D, "last word");

        // ---- byte loads (little-endian) ----
        load(32'h1001_0000, 1, 1, v); expect_eq(v, 32'h44, "lbu byte0");
        load(32'h1001_0003, 1, 1, v); expect_eq(v, 32'h11, "lbu byte3");
        store(32'h1001_0004, 32'h0000_0080, 0);
        load(32'h1001_0004, 1, 0, v); expect_eq(v, 32'hFFFF_FF80, "lb sign-extend");
        load(32'h1001_0004, 1, 1, v); expect_eq(v, 32'h0000_0080, "lbu zero-extend");

        // ---- byte store only changes one byte ----
        store(32'h1001_0001, 32'h0000_00AB, 1);
        load (32'h1001_0000, 0, 0, v); expect_eq(v, 32'h1122_AB44, "sb byte1");
        store(32'h1001_0003, 32'hFFFF_FF99, 1);
        load (32'h1001_0000, 0, 0, v); expect_eq(v, 32'h9922_AB44, "sb byte3");

        // ---- line port returns 4 words ----
        store(32'h1001_0010, 32'h0000_0001, 0);
        store(32'h1001_0014, 32'h0000_0002, 0);
        store(32'h1001_0018, 32'h0000_0003, 0);
        store(32'h1001_001C, 32'h0000_0004, 0);
        @(negedge clk); addr = 32'h1001_0018; #1;
        expect_eq(line[31:0],   1, "line word0");
        expect_eq(line[127:96], 4, "line word3");

        // ---- error detection ----
        @(negedge clk); addr = 32'h1001_0002; bytemode = 0; re = 1; #1;
        expect_eq(misaligned, 1, "misaligned lw");
        bytemode = 1; #1;
        expect_eq(misaligned, 0, "lb any alignment");
        addr = 32'h2000_0000; #1;
        expect_eq(bad_addr, 1, "unmapped address");
        re = 0;

        // ---- memory-mapped I/O ----
        @(negedge clk); addr = 32'hFFFF_0000; wdata = 32'd99; bytemode = 0; we = 1; #1;
        expect_eq(out_valid, 1, "OUT strobe");
        expect_eq(out_data, 99, "OUT data");
        expect_eq(r_we, 0, "I/O write not sent to RAM");
        @(negedge clk); we = 0;
        load(32'hFFFF_0000, 0, 0, v); expect_eq(v, 99, "OUT read back");
        store(32'hFFFF_0008, 32'h0000_00A5, 0);
        expect_eq(leds, 8'hA5, "LED register");
        load(32'hFFFF_000C, 0, 0, v);
        tests = tests + 1; if (v == 0) begin errors = errors + 1; $display("  FAIL cycle counter"); end
        expect_eq(halted, 0, "not halted");
        store(32'hFFFF_0004, 32'd1, 0);
        expect_eq(halted, 1, "HALT register");

        // ---- instruction memory ----
        imem.mem[0] = 32'h2008_0005; imem.mem[1] = 32'h2009_0007; #1;
        expect_eq(instr, 32'h2008_0005, "imem word0");
        iaddr = 32'h0040_0004; #1;
        expect_eq(instr, 32'h2009_0007, "imem word1");

        if (errors == 0) $display("PASS: tb_memory (%0d tests)", tests);
        else             $display("FAIL: tb_memory (%0d of %0d tests failed)", errors, tests);
        $finish;
    end
endmodule
