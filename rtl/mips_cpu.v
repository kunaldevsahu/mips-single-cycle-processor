// ============================================================================
// mips_cpu.v - Single-Cycle MIPS Processor Core (datapath + control)
// Owner : Kunal Dev Sahu (integration of every team member's module)
//
// Every instruction completes in ONE clock cycle:
//   Fetch   : PC -> instruction memory
//   Decode  : control unit + register file read + immediate extension
//   Execute : ALU
//   Memory  : data memory / I/O through the memory interface
//   Write   : result written to the register file on the rising clock edge,
//             and the PC is updated at the same edge
//
// Module ownership:
//   pc_reg, next_pc, mux2/mux3 ........ Pranav Singh
//   reg_file, sign_extend .............. Himanshu Pal
//   alu, alu_control ................... Vaibhav Singh
//   control_unit, this file ............ Kunal Dev Sahu
//   (memories / memory interface live in mips_top.v - Kevish Sewliya)
// ============================================================================
`include "defines.vh"

module mips_cpu (
    input  wire        clk,
    input  wire        rst,
    input  wire        halt,          // from MMIO: freeze the processor
    // instruction memory port
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_data,
    // data memory port (goes to mem_controller)
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire        dmem_re,
    output wire        dmem_we,
    output wire        dmem_byte,
    output wire        dmem_unsigned,
    input  wire [31:0] dmem_rdata
);
    // ---------------- instruction fields ----------------
    wire [31:0] pc, pc_plus4, pc_next;
    wire [31:0] instr  = imem_data;
    wire [5:0]  opcode = instr[31:26];
    wire [4:0]  rs     = instr[25:21];
    wire [4:0]  rt     = instr[20:16];
    wire [4:0]  rd     = instr[15:11];
    wire [4:0]  shamt  = instr[10:6];
    wire [5:0]  funct  = instr[5:0];
    wire [15:0] imm    = instr[15:0];
    wire [25:0] jidx   = instr[25:0];

    assign imem_addr = pc;

    // ---------------- control ----------------
    wire [1:0] reg_dst, mem_to_reg;
    wire [2:0] alu_op;
    wire alu_src, reg_write, mem_read, mem_write, mem_byte, mem_unsigned;
    wire branch, branch_ne, jump, jump_reg, ext_op;

    control_unit u_ctrl (
        .opcode(opcode), .funct(funct),
        .reg_dst(reg_dst), .alu_src(alu_src), .mem_to_reg(mem_to_reg),
        .reg_write(reg_write), .mem_read(mem_read), .mem_write(mem_write),
        .mem_byte(mem_byte), .mem_unsigned(mem_unsigned),
        .branch(branch), .branch_ne(branch_ne), .jump(jump), .jump_reg(jump_reg),
        .ext_op(ext_op), .alu_op(alu_op)
    );

    // ---------------- PC ----------------
    pc_reg u_pc (.clk(clk), .rst(rst), .stall(halt), .next_pc(pc_next), .pc(pc));

    // ---------------- register file ----------------
    wire [4:0]  write_reg;
    wire [31:0] write_data, rs_data, rt_data;

    mux3 #(5) u_mux_regdst (.d0(rt), .d1(rd), .d2(5'd31), .sel(reg_dst), .y(write_reg));

    reg_file u_rf (
        .clk(clk), .rst(rst), .we(reg_write & ~halt),
        .ra1(rs), .ra2(rt), .wa(write_reg), .wd(write_data),
        .rd1(rs_data), .rd2(rt_data)
    );

    // ---------------- immediate ----------------
    wire [31:0] imm_ext;
    sign_extend u_ext (.imm(imm), .ext_op(ext_op), .imm_ext(imm_ext));

    // ---------------- ALU ----------------
    wire [31:0] alu_b, alu_result;
    wire [3:0]  alu_ctrl;
    wire        zero, overflow;

    mux2 #(32) u_mux_alusrc (.d0(rt_data), .d1(imm_ext), .sel(alu_src), .y(alu_b));
    alu_control u_aluctl (.alu_op(alu_op), .funct(funct), .alu_ctrl(alu_ctrl));
    alu u_alu (
        .a(rs_data), .b(alu_b), .shamt(shamt), .alu_ctrl(alu_ctrl),
        .result(alu_result), .zero(zero), .overflow(overflow)
    );

    // ---------------- data memory interface ----------------
    assign dmem_addr     = alu_result;
    assign dmem_wdata    = rt_data;
    assign dmem_re       = mem_read  & ~halt;
    assign dmem_we       = mem_write & ~halt;
    assign dmem_byte     = mem_byte;
    assign dmem_unsigned = mem_unsigned;

    // ---------------- write-back ----------------
    mux3 #(32) u_mux_wb (.d0(alu_result), .d1(dmem_rdata), .d2(pc_plus4),
                         .sel(mem_to_reg), .y(write_data));

    // ---------------- next PC ----------------
    wire branch_taken;
    next_pc u_npc (
        .pc(pc), .imm_ext(imm_ext), .jump_index(jidx), .rs_data(rs_data),
        .branch(branch), .branch_ne(branch_ne), .zero(zero),
        .jump(jump), .jump_reg(jump_reg),
        .pc_plus4(pc_plus4), .next_pc(pc_next), .branch_taken(branch_taken)
    );
endmodule
