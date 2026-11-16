// ============================================================================
// cache.v - Direct-Mapped Data Cache with hit/miss statistics
// Owner : Kunal Dev Sahu
//
// Organisation : 16 lines x 4 words (16 bytes per block) = 256 bytes of data
// Address split: | tag [31:8] | index [7:4] | word offset [3:2] | byte [1:0] |
// Policies     : read miss  -> fetch the whole block from RAM (spatial locality)
//                write      -> write-through (RAM is always up to date)
//                write hit  -> also update the cached word
//                write miss -> no-write-allocate
//
// In a single-cycle CPU the RAM answers in the same cycle, so the cache does
// not change timing in simulation. Instead it COUNTS hits and misses so we can
// measure locality and compute AMAT = hit_time + miss_rate * miss_penalty.
// ============================================================================
module cache #(
    parameter LINES = 16                 // must be 16 for the index width below
) (
    input  wire         clk,
    input  wire         rst,
    // ---------------- from memory controller ----------------
    input  wire [31:0]  addr,
    input  wire         re,
    input  wire         we,
    input  wire [3:0]   be,
    input  wire [31:0]  wdata,
    output wire [31:0]  rdata,
    // ---------------- to data RAM ----------------
    output wire [31:0]  mem_addr,
    output wire         mem_we,
    output wire [3:0]   mem_be,
    output wire [31:0]  mem_wdata,
    input  wire [127:0] mem_line,        // block read from RAM
    // ---------------- statistics ----------------
    output reg  [31:0]  read_hits,
    output reg  [31:0]  read_misses,
    output reg  [31:0]  write_hits,
    output reg  [31:0]  write_misses
);
    reg [23:0]  tags  [0:LINES-1];
    reg [127:0] data  [0:LINES-1];
    reg         valid [0:LINES-1];
    integer i;

    wire [23:0] tag    = addr[31:8];
    wire [3:0]  index  = addr[7:4];
    wire [1:0]  offset = addr[3:2];

    wire hit = valid[index] && (tags[index] == tag);

    // ---- read path: hit -> cached word, miss -> word straight from RAM block ----
    wire [127:0] line   = hit ? data[index] : mem_line;
    assign rdata = line[offset*32 +: 32];

    // ---- write-through: every write goes to RAM ----
    assign mem_addr  = addr;
    assign mem_we    = we;
    assign mem_be    = be;
    assign mem_wdata = wdata;

    // byte-merge for a write hit
    wire [31:0] old_word = data[index][offset*32 +: 32];
    wire [31:0] new_word = { be[3] ? wdata[31:24] : old_word[31:24],
                             be[2] ? wdata[23:16] : old_word[23:16],
                             be[1] ? wdata[15:8]  : old_word[15:8],
                             be[0] ? wdata[7:0]   : old_word[7:0] };

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < LINES; i = i + 1) begin
                valid[i] <= 1'b0;
                tags[i]  <= 24'b0;
                data[i]  <= 128'b0;
            end
            read_hits    <= 0;
            read_misses  <= 0;
            write_hits   <= 0;
            write_misses <= 0;
        end else begin
            if (re) begin
                if (hit) read_hits <= read_hits + 1;
                else begin
                    read_misses  <= read_misses + 1;
                    data[index]  <= mem_line;     // allocate block on read miss
                    tags[index]  <= tag;
                    valid[index] <= 1'b1;
                end
            end
            if (we) begin
                if (hit) begin
                    write_hits <= write_hits + 1;
                    data[index][offset*32 +: 32] <= new_word;
                end else
                    write_misses <= write_misses + 1;
            end
        end
    end
endmodule
