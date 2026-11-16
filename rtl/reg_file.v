// ============================================================================
// reg_file.v - 32 x 32-bit MIPS Register File
// Owner : Himanshu Pal
//
// * Two asynchronous (combinational) read ports  -> rs and rt read in the same cycle
// * One synchronous write port (rising clock edge) -> result written at end of cycle
// * Register $0 is hard-wired to zero (writes to it are ignored)
// ============================================================================
module reg_file (
    input  wire        clk,
    input  wire        rst,        // synchronous reset: clears all registers
    input  wire        we,         // write enable (RegWrite)
    input  wire [4:0]  ra1,        // read address 1 (rs)
    input  wire [4:0]  ra2,        // read address 2 (rt)
    input  wire [4:0]  wa,         // write address (rt / rd / $ra)
    input  wire [31:0] wd,         // write data
    output wire [31:0] rd1,        // read data 1
    output wire [31:0] rd2         // read data 2
);
    reg [31:0] regs [0:31];
    integer i;

    // Read: $0 always returns 0
    assign rd1 = (ra1 == 5'd0) ? 32'b0 : regs[ra1];
    assign rd2 = (ra2 == 5'd0) ? 32'b0 : regs[ra2];

    // Write on the rising edge of the clock
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'b0;
        end else if (we && (wa != 5'd0)) begin
            regs[wa] <= wd;
        end
    end
endmodule
