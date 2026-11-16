// ============================================================================
// alu_control.v - ALU Control Unit
// Owner : Vaibhav Singh
//
// Second level of decoding. The main control unit only says WHAT KIND of
// instruction this is (alu_op). For R-type instructions this unit looks at
// the funct field to pick the exact ALU operation.
// ============================================================================
`include "defines.vh"

module alu_control (
    input  wire [2:0] alu_op,    // from main control unit
    input  wire [5:0] funct,     // instr[5:0]
    output reg  [3:0] alu_ctrl   // to ALU
);
    always @(*) begin
        case (alu_op)
            `ALUOP_ADD: alu_ctrl = `ALU_ADD;
            `ALUOP_SUB: alu_ctrl = `ALU_SUB;
            `ALUOP_AND: alu_ctrl = `ALU_AND;
            `ALUOP_OR : alu_ctrl = `ALU_OR;
            `ALUOP_XOR: alu_ctrl = `ALU_XOR;
            `ALUOP_SLT: alu_ctrl = `ALU_SLT;
            `ALUOP_LUI: alu_ctrl = `ALU_LUI;
            `ALUOP_RTYPE: begin
                case (funct)
                    `FN_ADD, `FN_ADDU: alu_ctrl = `ALU_ADD;
                    `FN_SUB, `FN_SUBU: alu_ctrl = `ALU_SUB;
                    `FN_AND:           alu_ctrl = `ALU_AND;
                    `FN_OR :           alu_ctrl = `ALU_OR;
                    `FN_XOR:           alu_ctrl = `ALU_XOR;
                    `FN_NOR:           alu_ctrl = `ALU_NOR;
                    `FN_SLT:           alu_ctrl = `ALU_SLT;
                    `FN_SLL:           alu_ctrl = `ALU_SLL;
                    `FN_SRL:           alu_ctrl = `ALU_SRL;
                    `FN_SRA:           alu_ctrl = `ALU_SRA;
                    default:           alu_ctrl = `ALU_ADD; // jr and unknown: harmless
                endcase
            end
            default: alu_ctrl = `ALU_ADD;
        endcase
    end
endmodule
