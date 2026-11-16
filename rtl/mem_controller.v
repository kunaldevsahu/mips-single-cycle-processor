// ============================================================================
// mem_controller.v - Memory Interface / Address Decoder
// Owner : Kevish Sewliya
//
// Sits between the CPU and the memory system. Responsibilities:
//  1. Address decoding  : send the access to data RAM or to memory-mapped I/O
//       0x1001_0000 - 0x1001_0FFF  -> data RAM (through the cache)
//       0xFFFF_0000 - 0xFFFF_FFFF  -> I/O registers (mmio.v)
//  2. Byte lanes        : turn sb into the right byte-enable and shifted data
//  3. Load formatting   : pick the right byte for lb / lbu and sign/zero extend
//  4. Error detection   : flag misaligned word accesses and unmapped addresses
// The CPU itself only produces an address, data and a few control bits.
// ============================================================================
module mem_controller (
    // ---------------- CPU side ----------------
    input  wire [31:0] cpu_addr,
    input  wire [31:0] cpu_wdata,
    input  wire        cpu_re,        // MemRead
    input  wire        cpu_we,        // MemWrite
    input  wire        cpu_byte,      // 1 = byte access (lb/lbu/sb), 0 = word
    input  wire        cpu_unsigned,  // 1 = lbu (zero-extend)
    output wire [31:0] cpu_rdata,
    // ---------------- RAM side (goes to cache) ----------------
    output wire [31:0] ram_addr,      // word-aligned address
    output wire        ram_re,
    output wire        ram_we,
    output wire [3:0]  ram_be,
    output wire [31:0] ram_wdata,
    input  wire [31:0] ram_rdata,
    // ---------------- I/O side ----------------
    output wire [3:0]  io_reg,        // which I/O register (address bits 5:2)
    output wire        io_re,
    output wire        io_we,
    output wire [31:0] io_wdata,
    input  wire [31:0] io_rdata,
    // ---------------- status ----------------
    output wire        misaligned,
    output wire        bad_addr
);
    wire access = cpu_re | cpu_we;

    // 1. address decode
    wire sel_ram = (cpu_addr[31:12] == 20'h10010);
    wire sel_io  = (cpu_addr[31:16] == 16'hFFFF);

    assign bad_addr   = access & ~sel_ram & ~sel_io;
    assign misaligned = access & ~cpu_byte & (cpu_addr[1:0] != 2'b00);

    // 2. byte lanes for stores (little-endian, like MARS)
    wire [1:0] off = cpu_addr[1:0];
    wire [3:0] be  = cpu_byte ? (4'b0001 << off) : 4'b1111;
    wire [31:0] wd = cpu_byte ? {4{cpu_wdata[7:0]}} : cpu_wdata;

    assign ram_addr  = {cpu_addr[31:2], 2'b00};
    assign ram_re    = cpu_re & sel_ram;
    assign ram_we    = cpu_we & sel_ram & ~misaligned;
    assign ram_be    = be;
    assign ram_wdata = wd;

    assign io_reg    = cpu_addr[5:2];
    assign io_re     = cpu_re & sel_io;
    assign io_we     = cpu_we & sel_io;
    assign io_wdata  = cpu_wdata;

    // 3. load formatting
    wire [31:0] raw  = sel_ram ? ram_rdata : (sel_io ? io_rdata : 32'b0);
    wire [7:0]  byte_sel = raw >> (8 * off);
    wire [31:0] byte_ext = cpu_unsigned ? {24'b0, byte_sel} : {{24{byte_sel[7]}}, byte_sel};

    assign cpu_rdata = cpu_byte ? byte_ext : raw;
endmodule
