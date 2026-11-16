// ============================================================================
// tb_mips_top.v - Full-system testbench: runs a whole program on the CPU
// Owner : Kunal Dev Sahu
//
// Plusargs (run_tests.py passes these automatically):
//   +PROG=build/x.hex        instruction memory image   (required)
//   +DATA=build/x_data.hex   data memory image          (optional)
//   +EXPECT=programs/x.expected  expected OUT values    (optional)
//   +VCD=build/x.vcd         dump waveforms for GTKWave (optional)
//   +REGS                    print the register file at the end
//   +TRACE                   print every instruction as it executes
//   +MAXCYC=n                timeout (default 100000 cycles)
// ============================================================================
`timescale 1ns/1ps

module tb_mips_top;
    reg clk = 0, rst = 1;
    wire halted, out_valid, mem_error;
    wire [31:0] out_data;
    wire [7:0]  leds;

    mips_top dut (.clk(clk), .rst(rst), .halted(halted), .out_valid(out_valid),
                  .out_data(out_data), .leds(leds), .mem_error(mem_error));

    always #5 clk = ~clk;   // 100 MHz clock (10 ns period)

    // ---------------- cache model parameters for AMAT ----------------
    localparam HIT_TIME     = 1;    // cycles
    localparam MISS_PENALTY = 20;   // cycles to fetch a block from main memory

    reg [1023:0] prog_file, data_file, exp_file, vcd_file;
    reg [31:0]   expected [0:255];
    reg [31:0]   got      [0:255];
    integer n_exp = 0, n_got = 0, cycles = 0, max_cyc = 100000, i, errors = 0;
    integer rh, rm, wh, wm;

    // record every value written to the OUT port (sample at falling edge)
    always @(negedge clk) begin
        if (!rst && out_valid && !halted) begin
            if (n_got < 256) got[n_got] = out_data;
            n_got = n_got + 1;
            $display("  [OUT] %0d  (0x%08h)", $signed(out_data), out_data);
        end
        if (!rst && mem_error && !halted) begin
            $display("  ERROR: bad memory access at PC=0x%08h addr=0x%08h",
                     dut.u_cpu.pc, dut.d_addr);
            errors = errors + 1;
        end
        if (!rst && !halted && $test$plusargs("TRACE"))
            $display("  PC=0x%08h  instr=0x%08h", dut.u_cpu.pc, dut.imem_data);
    end

    initial begin
        for (i = 0; i < 256; i = i + 1) expected[i] = 32'bx;

        if (!$value$plusargs("PROG=%s", prog_file)) begin
            $display("ERROR: give the program with +PROG=<file.hex>");
            $finish;
        end
        $readmemh(prog_file, dut.u_imem.mem);
        if ($value$plusargs("DATA=%s", data_file))
            $readmemh(data_file, dut.u_dmem.mem);
        if ($value$plusargs("EXPECT=%s", exp_file)) begin
            $readmemh(exp_file, expected);
            while (n_exp < 256 && expected[n_exp] !== 32'bx) n_exp = n_exp + 1;
        end
        if ($value$plusargs("VCD=%s", vcd_file)) begin
            $dumpfile(vcd_file);
            $dumpvars(0, tb_mips_top);
        end
        if ($value$plusargs("MAXCYC=%d", max_cyc)) ;

        // reset for 2 cycles
        repeat (2) @(posedge clk);
        #1 rst = 0;

        // run until the program writes to the HALT register
        while (!halted && cycles < max_cyc) begin
            @(posedge clk); #1;      // let the clock edge's register updates settle
            cycles = cycles + 1;
        end
        @(negedge clk);

        // ---------------- report ----------------
        $display("----------------------------------------------------------");
        if (!halted) begin
            $display("  TIMEOUT after %0d cycles (PC=0x%08h)", cycles, dut.u_cpu.pc);
            errors = errors + 1;
        end else
            $display("  Halted after %0d cycles (= %0d instructions, CPI = 1)", cycles, cycles);

        if (n_exp > 0) begin
            if (n_got != n_exp) begin
                $display("  MISMATCH: %0d outputs, expected %0d", n_got, n_exp);
                errors = errors + 1;
            end
            for (i = 0; i < n_exp && i < n_got; i = i + 1)
                if (got[i] !== expected[i]) begin
                    $display("  MISMATCH output #%0d: got 0x%08h expected 0x%08h",
                             i, got[i], expected[i]);
                    errors = errors + 1;
                end
        end

        rh = dut.u_cache.read_hits;  rm = dut.u_cache.read_misses;
        wh = dut.u_cache.write_hits; wm = dut.u_cache.write_misses;
        $display("  Cache: reads %0d (hits %0d, misses %0d), writes %0d (hits %0d, misses %0d)",
                 rh + rm, rh, rm, wh + wm, wh, wm);
        if (rh + rm > 0)
            $display("  Read hit rate = %0.1f %%   AMAT = %0d + %0.3f x %0d = %0.2f cycles",
                     100.0 * rh / (rh + rm), HIT_TIME, 1.0 * rm / (rh + rm), MISS_PENALTY,
                     HIT_TIME + (1.0 * rm / (rh + rm)) * MISS_PENALTY);

        if ($test$plusargs("REGS")) begin
            $display("  Register file:");
            for (i = 0; i < 32; i = i + 1)
                if (dut.u_cpu.u_rf.regs[i] != 0)
                    $display("    $%0d = 0x%08h (%0d)", i, dut.u_cpu.u_rf.regs[i],
                             $signed(dut.u_cpu.u_rf.regs[i]));
        end

        if (errors == 0 && n_exp > 0) $display("RESULT: PASS (%0d outputs checked)", n_exp);
        else if (errors == 0)         $display("RESULT: DONE (no expected file given)");
        else                          $display("RESULT: FAIL (%0d errors)", errors);
        $finish;
    end
endmodule
