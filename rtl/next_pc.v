// ============================================================================
// next_pc.v - Next-PC / Branch / Jump logic
// Owner : Pranav Singh
//
// Decides which instruction runs next:
//   jr            : PC = rs
//   j / jal       : PC = {PC+4[31:28], target, 00}        (pseudo-direct)
//   beq taken     : PC = PC+4 + (signext(imm) << 2)       (PC-relative)
//   bne taken     : same target, taken when the operands differ
//   otherwise     : PC = PC+4
// ============================================================================
module next_pc (
    input  wire [31:0] pc,
    input  wire [31:0] imm_ext,     // sign-extended immediate (branch offset)
    input  wire [25:0] jump_index,  // instr[25:0]
    input  wire [31:0] rs_data,     // register value for jr
    input  wire        branch,      // beq
    input  wire        branch_ne,   // bne
    input  wire        zero,        // ALU zero flag (rs - rt == 0)
    input  wire        jump,        // j / jal
    input  wire        jump_reg,    // jr
    output wire [31:0] pc_plus4,
    output wire [31:0] next_pc,
    output wire        branch_taken
);
    assign pc_plus4 = pc + 32'd4;

    wire [31:0] branch_target = pc_plus4 + {imm_ext[29:0], 2'b00};
    wire [31:0] jump_target   = {pc_plus4[31:28], jump_index, 2'b00};

    assign branch_taken = (branch & zero) | (branch_ne & ~zero);

    assign next_pc = jump_reg     ? rs_data       :
                     jump         ? jump_target   :
                     branch_taken ? branch_target :
                                    pc_plus4;
endmodule
