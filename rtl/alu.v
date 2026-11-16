// ============================================================================
// alu.v - 32-bit Arithmetic Logic Unit
// Owner : Vaibhav Singh
//
// Performs the arithmetic / logic / shift operation chosen by alu_ctrl.
// Addition and subtraction share one adder: SUB is A + (~B) + 1, exactly the
// adder-subtractor circuit from Unit 1 (two's complement).
// ============================================================================
`include "defines.vh"

module alu (
    input  wire [31:0] a,          // operand A (rs)
    input  wire [31:0] b,          // operand B (rt or immediate)
    input  wire [4:0]  shamt,      // shift amount (instr[10:6])
    input  wire [3:0]  alu_ctrl,   // operation select (from alu_control)
    output reg  [31:0] result,     // result
    output wire        zero,       // 1 when result == 0 (used by beq / bne)
    output wire        overflow    // signed overflow of ADD / SUB
);
    // ---- shared adder-subtractor ----
    wire        do_sub = (alu_ctrl == `ALU_SUB) || (alu_ctrl == `ALU_SLT);
    wire [31:0] b_in   = do_sub ? ~b : b;
    wire [31:0] sum    = a + b_in + {31'b0, do_sub};

    // Signed overflow: operands (after inversion) have same sign, result differs
    assign overflow = ((alu_ctrl == `ALU_ADD) || (alu_ctrl == `ALU_SUB)) &&
                      (a[31] == b_in[31]) && (sum[31] != a[31]);

    // Set-less-than (signed): if signs differ, the negative one is smaller;
    // otherwise the sign of (a - b) is correct (no overflow possible).
    wire less = (a[31] != b[31]) ? a[31] : sum[31];

    always @(*) begin
        case (alu_ctrl)
            `ALU_AND: result = a & b;
            `ALU_OR : result = a | b;
            `ALU_ADD: result = sum;
            `ALU_SUB: result = sum;
            `ALU_XOR: result = a ^ b;
            `ALU_NOR: result = ~(a | b);
            `ALU_SLT: result = {31'b0, less};
            `ALU_SLL: result = b << shamt;
            `ALU_SRL: result = b >> shamt;
            `ALU_SRA: result = $signed(b) >>> shamt;
            `ALU_LUI: result = {b[15:0], 16'b0};
            default : result = 32'b0;
        endcase
    end

    assign zero = (result == 32'b0);
endmodule
