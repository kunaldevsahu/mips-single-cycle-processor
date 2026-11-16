// ============================================================================
// mmio.v - Memory-Mapped I/O registers
// Owner : Kevish Sewliya
//
// A program talks to the outside world with ordinary lw / sw instructions:
//   reg 0  0xFFFF_0000  OUT  (W)  value written here appears on out_data
//                              for one cycle (out_valid = 1); the testbench
//                              prints and checks it. Read returns last value.
//   reg 1  0xFFFF_0004  HALT (W)  any write stops the processor
//   reg 2  0xFFFF_0008  LED  (RW) 8-bit LED register (for an FPGA board)
//   reg 3  0xFFFF_000C  CYCLE(R)  number of clock cycles since reset
// ============================================================================
module mmio (
    input  wire        clk,
    input  wire        rst,
    input  wire [3:0]  reg_sel,
    input  wire        re,
    input  wire        we,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    output wire        out_valid,   // strobe: OUT register written this cycle
    output wire [31:0] out_data,
    output reg         halted,
    output reg  [7:0]  leds
);
    reg [31:0] out_reg;
    reg [31:0] cycles;

    assign out_valid = we && (reg_sel == 4'd0);
    assign out_data  = wdata;

    always @(posedge clk) begin
        if (rst) begin
            out_reg <= 32'b0;
            halted  <= 1'b0;
            leds    <= 8'b0;
            cycles  <= 32'b0;
        end else begin
            cycles <= cycles + 1;
            if (we) begin
                case (reg_sel)
                    4'd0: out_reg <= wdata;
                    4'd1: halted  <= 1'b1;
                    4'd2: leds    <= wdata[7:0];
                    default: ;
                endcase
            end
        end
    end

    always @(*) begin
        case (reg_sel)
            4'd0:    rdata = out_reg;
            4'd1:    rdata = {31'b0, halted};
            4'd2:    rdata = {24'b0, leds};
            4'd3:    rdata = cycles;
            default: rdata = 32'b0;
        endcase
    end
endmodule
