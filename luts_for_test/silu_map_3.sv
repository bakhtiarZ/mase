module silu_lut(input logic [2:0] data_in_0, output logic [2:0] data_out_0);
    always_comb begin
        case(data_in_0)
            3'b000: data_out_0 = 3'b000;
            3'b001: data_out_0 = 3'b001;
            3'b010: data_out_0 = 3'b010;
            3'b011: data_out_0 = 3'b011;
            3'b100: data_out_0 = 3'b000;
            3'b101: data_out_0 = 3'b000;
            3'b110: data_out_0 = 3'b000;
            3'b111: data_out_0 = 3'b000;
            default: data_out_0 = 3'b0;
        endcase
    end
endmodule
