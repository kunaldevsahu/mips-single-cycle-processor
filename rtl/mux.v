// ============================================================================
// mux.v - Parameterised multiplexers used in the datapath
// Owner : Pranav Singh
// ============================================================================

// 2-to-1 multiplexer
module mux2 #(parameter W = 32) (
    input  wire [W-1:0] d0,
    input  wire [W-1:0] d1,
    input  wire         sel,
    output wire [W-1:0] y
);
    assign y = sel ? d1 : d0;
endmodule

// 3-to-1 multiplexer (sel = 2'b11 also returns d2)
module mux3 #(parameter W = 32) (
    input  wire [W-1:0] d0,
    input  wire [W-1:0] d1,
    input  wire [W-1:0] d2,
    input  wire [1:0]   sel,
    output wire [W-1:0] y
);
    assign y = (sel == 2'b00) ? d0 :
               (sel == 2'b01) ? d1 : d2;
endmodule
