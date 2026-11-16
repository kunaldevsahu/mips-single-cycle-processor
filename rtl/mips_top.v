// ============================================================================
// mips_top.v - Complete system: CPU + memories + memory interface + I/O
// Owner : Kunal Dev Sahu
//
//            +-----------+      +-------------+
//   PC ----> | instr_mem |      |             |
//            +-----------+      |             |
//                 |             |  mips_cpu   |
//                 +-----------> |             |
//                               +------+------+
//                                      | addr / data / re / we / byte
//                               +------v---------+
//                               | mem_controller |  (address decode, byte lanes)
//                               +---+--------+---+
//                       RAM range   |        |   I/O range
//                               +---v---+  +-v----+
//                               | cache |  | mmio |  OUT / HALT / LED / CYCLE
//                               +---+---+  +------+
//                                   |
//                               +---v------+
//                               | data_mem |
//                               +----------+
// ============================================================================
module mips_top #(
    parameter IMEM_FILE = "",
    parameter DMEM_FILE = ""
) (
    input  wire        clk,
    input  wire        rst,
    output wire        halted,
    output wire        out_valid,
    output wire [31:0] out_data,
    output wire [7:0]  leds,
    output wire        mem_error      // misaligned or unmapped access
);
    // CPU <-> instruction memory
    wire [31:0] imem_addr, imem_data;
    // CPU <-> memory controller
    wire [31:0] d_addr, d_wdata, d_rdata;
    wire        d_re, d_we, d_byte, d_unsigned;
    // memory controller <-> cache
    wire [31:0] r_addr, r_wdata, r_rdata;
    wire        r_re, r_we;
    wire [3:0]  r_be;
    // memory controller <-> mmio
    wire [3:0]  io_reg;
    wire        io_re, io_we;
    wire [31:0] io_wdata, io_rdata;
    // cache <-> data memory
    wire [31:0]  m_addr, m_wdata;
    wire         m_we;
    wire [3:0]   m_be;
    wire [127:0] m_line;
    wire [31:0]  m_rdata_unused;
    wire         misaligned, bad_addr;

    mips_cpu u_cpu (
        .clk(clk), .rst(rst), .halt(halted),
        .imem_addr(imem_addr), .imem_data(imem_data),
        .dmem_addr(d_addr), .dmem_wdata(d_wdata), .dmem_re(d_re), .dmem_we(d_we),
        .dmem_byte(d_byte), .dmem_unsigned(d_unsigned), .dmem_rdata(d_rdata)
    );

    instr_mem #(.MEM_FILE(IMEM_FILE)) u_imem (.addr(imem_addr), .instr(imem_data));

    mem_controller u_memctl (
        .cpu_addr(d_addr), .cpu_wdata(d_wdata), .cpu_re(d_re), .cpu_we(d_we),
        .cpu_byte(d_byte), .cpu_unsigned(d_unsigned), .cpu_rdata(d_rdata),
        .ram_addr(r_addr), .ram_re(r_re), .ram_we(r_we), .ram_be(r_be),
        .ram_wdata(r_wdata), .ram_rdata(r_rdata),
        .io_reg(io_reg), .io_re(io_re), .io_we(io_we), .io_wdata(io_wdata),
        .io_rdata(io_rdata),
        .misaligned(misaligned), .bad_addr(bad_addr)
    );

    cache u_cache (
        .clk(clk), .rst(rst),
        .addr(r_addr), .re(r_re), .we(r_we), .be(r_be), .wdata(r_wdata), .rdata(r_rdata),
        .mem_addr(m_addr), .mem_we(m_we), .mem_be(m_be), .mem_wdata(m_wdata),
        .mem_line(m_line),
        .read_hits(), .read_misses(), .write_hits(), .write_misses()
    );

    data_mem #(.MEM_FILE(DMEM_FILE)) u_dmem (
        .clk(clk), .addr(m_addr), .we(m_we), .be(m_be), .wdata(m_wdata),
        .rdata(m_rdata_unused), .line_addr(m_addr), .line_data(m_line)
    );

    mmio u_mmio (
        .clk(clk), .rst(rst), .reg_sel(io_reg), .re(io_re), .we(io_we),
        .wdata(io_wdata), .rdata(io_rdata),
        .out_valid(out_valid), .out_data(out_data), .halted(halted), .leds(leds)
    );

    assign mem_error = misaligned | bad_addr;
endmodule
