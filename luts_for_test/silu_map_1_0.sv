module silu_lut_1_0(input logic [0:0] data_in_0, output logic [0:0] data_out_0);
    always_comb begin
        case(data_in_0)
            1'b0: data_out_0 = 1'b0;
            1'b1: data_out_0 = 1'b0;
            default: data_out_0 = 1'b0;
        endcase
    end
endmodule
