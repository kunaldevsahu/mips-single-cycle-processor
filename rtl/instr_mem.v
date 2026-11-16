// ============================================================================
// instr_mem.v - Instruction Memory (read-only, Harvard architecture)
// Owner : Kevish Sewliya
//
// 1024 words (4 KB). Word-addressed with addr[11:2] because every MIPS
// instruction is 4 bytes and aligned. The program is loaded from a .hex
// file (one 32-bit word per line) produced by tools/assembler.py.
// Read is combinational, so the instruction is available in the same cycle.
// ============================================================================
module instr_mem #(
    parameter DEPTH    = 1024,
    parameter MEM_FILE = ""          // optional program file for synthesis/FPGA
) (
    input  wire [31:0] addr,         // byte address from PC
    output wire [31:0] instr
);
    reg [31:0] mem [0:DEPTH-1];
    integer i;

    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'h0000_0000;      // 0x00000000 = nop (sll $0,$0,0)
        if (MEM_FILE != "")
            $readmemh(MEM_FILE, mem);
    end

    assign instr = mem[addr[11:2]];
endmodule
