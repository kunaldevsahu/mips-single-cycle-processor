// ============================================================================
// pc_reg.v - Program Counter register
// Owner : Pranav Singh
//
// Holds the address of the instruction being executed. On every rising clock
// edge it loads next_pc, unless the processor is halted (stall = 1).
// Reset value is 0x0040_0000, the start of the text segment (same as MARS).
// ============================================================================
`include "defines.vh"

module pc_reg (
    input  wire        clk,
    input  wire        rst,
    input  wire        stall,     // 1 = keep current PC (used when halted)
    input  wire [31:0] next_pc,
    output reg  [31:0] pc
);
    always @(posedge clk) begin
        if (rst)
            pc <= `TEXT_BASE;
        else if (!stall)
            pc <= next_pc;
    end
endmodule
