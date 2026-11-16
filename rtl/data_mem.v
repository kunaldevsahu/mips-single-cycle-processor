// ============================================================================
// data_mem.v - Data Memory (RAM) with byte enables
// Owner : Kevish Sewliya
//
// 1024 words (4 KB) mapped at 0x1001_0000 (same as the MARS .data segment).
// * Word read port   : rdata = mem[addr[11:2]]  (combinational)
// * Line read port   : returns 4 consecutive words (16 bytes) so the cache
//                      can fill a whole block in one go
// * Write port       : synchronous, each of the 4 bytes has its own enable
//                      (be[0] = bits 7:0 ... be[3] = bits 31:24, little-endian)
// ============================================================================
module data_mem #(
    parameter DEPTH    = 1024,
    parameter MEM_FILE = ""
) (
    input  wire         clk,
    input  wire [31:0]  addr,       // byte address (word aligned)
    input  wire         we,
    input  wire [3:0]   be,         // byte enables
    input  wire [31:0]  wdata,
    output wire [31:0]  rdata,
    input  wire [31:0]  line_addr,  // byte address inside the wanted block
    output wire [127:0] line_data   // {word3, word2, word1, word0}
);
    reg [31:0] mem [0:DEPTH-1];
    integer i;

    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'h0;
        if (MEM_FILE != "")
            $readmemh(MEM_FILE, mem);
    end

    wire [9:0] widx = addr[11:2];
    wire [9:0] lidx = {line_addr[11:4], 2'b00};

    assign rdata     = mem[widx];
    assign line_data = {mem[lidx + 3], mem[lidx + 2], mem[lidx + 1], mem[lidx]};

    always @(posedge clk) begin
        if (we) begin
            if (be[0]) mem[widx][7:0]   <= wdata[7:0];
            if (be[1]) mem[widx][15:8]  <= wdata[15:8];
            if (be[2]) mem[widx][23:16] <= wdata[23:16];
            if (be[3]) mem[widx][31:24] <= wdata[31:24];
        end
    end
endmodule
