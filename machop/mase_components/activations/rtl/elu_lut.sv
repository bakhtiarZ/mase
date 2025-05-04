
`timescale 1ns / 1ps
/* verilator lint_off UNUSEDPARAM */
module elu_lut #(
    parameter DATA_IN_0_PRECISION_0 = 16,
    parameter DATA_IN_0_PRECISION_1 = 8,
    parameter DATA_OUT_0_PRECISION_0 = 16,
    parameter DATA_OUT_0_PRECISION_1 = 8
)
(
    /* verilator lint_off UNUSEDSIGNAL */
    input logic [1:0] data_in_0, 
    output logic [1:0] data_out_0
);
    
    always_comb begin
        case(data_in_0)
            2'b00: data_out_0 = 2'b00;
            2'b01: data_out_0 = 2'b01;
            2'b10: data_out_0 = 2'b10;
            2'b11: data_out_0 = 2'b11;
            default: data_out_0 = 2'b0;
        endcase
    end
endmodule
