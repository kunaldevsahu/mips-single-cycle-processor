// ============================================================================
// defines.vh - Shared constants for the Single-Cycle MIPS Processor
// Project : Single-Cycle MIPS Processor with Memory Interface (Team Vaibhav Ke Veer)
// Owner   : Kunal Dev Sahu (shared interface spec used by every module)
// ============================================================================
`ifndef MIPS_DEFINES_VH
`define MIPS_DEFINES_VH

// ---------------- Opcodes (instr[31:26]) ----------------
`define OP_RTYPE  6'h00
`define OP_J      6'h02
`define OP_JAL    6'h03
`define OP_BEQ    6'h04
`define OP_BNE    6'h05
`define OP_ADDI   6'h08
`define OP_ADDIU  6'h09
`define OP_SLTI   6'h0A
`define OP_ANDI   6'h0C
`define OP_ORI    6'h0D
`define OP_XORI   6'h0E
`define OP_LUI    6'h0F
`define OP_LB     6'h20
`define OP_LW     6'h23
`define OP_LBU    6'h24
`define OP_SB     6'h28
`define OP_SW     6'h2B

// ---------------- Function codes (instr[5:0], R-type) ----------------
`define FN_SLL    6'h00
`define FN_SRL    6'h02
`define FN_SRA    6'h03
`define FN_JR     6'h08
`define FN_ADD    6'h20
`define FN_ADDU   6'h21
`define FN_SUB    6'h22
`define FN_SUBU   6'h23
`define FN_AND    6'h24
`define FN_OR     6'h25
`define FN_XOR    6'h26
`define FN_NOR    6'h27
`define FN_SLT    6'h2A

// ---------------- ALUOp (main control -> ALU control), 3 bits ----------------
`define ALUOP_ADD   3'b000   // lw, sw, lb, lbu, sb, addi, addiu
`define ALUOP_SUB   3'b001   // beq, bne
`define ALUOP_RTYPE 3'b010   // look at funct field
`define ALUOP_AND   3'b011   // andi
`define ALUOP_OR    3'b100   // ori
`define ALUOP_XOR   3'b101   // xori
`define ALUOP_SLT   3'b110   // slti
`define ALUOP_LUI   3'b111   // lui

// ---------------- ALU control codes (ALU control -> ALU), 4 bits ----------------
`define ALU_AND   4'b0000
`define ALU_OR    4'b0001
`define ALU_ADD   4'b0010
`define ALU_XOR   4'b0011
`define ALU_NOR   4'b0100
`define ALU_SUB   4'b0110
`define ALU_SLT   4'b0111
`define ALU_SLL   4'b1000
`define ALU_SRL   4'b1001
`define ALU_SRA   4'b1010
`define ALU_LUI   4'b1011

// ---------------- Memory map ----------------
`define TEXT_BASE   32'h0040_0000   // reset PC (same as MARS simulator)
`define DATA_BASE   32'h1001_0000   // start of data RAM (same as MARS .data)
`define IO_OUT      32'hFFFF_0000   // write: output port (value is printed)
`define IO_HALT     32'hFFFF_0004   // write: stop the processor
`define IO_LED      32'hFFFF_0008   // read/write: 8-bit LED register

`endif
