module silu_lut(input logic [4:0] data_in_0, output logic [4:0] data_out_0);
    always_comb begin
        case(data_in_0)
            5'b00000: data_out_0 = 5'b00000;
            5'b00001: data_out_0 = 5'b00001;
            5'b00010: data_out_0 = 5'b00010;
            5'b00011: data_out_0 = 5'b00011;
            5'b00100: data_out_0 = 5'b00100;
            5'b00101: data_out_0 = 5'b00101;
            5'b00110: data_out_0 = 5'b00110;
            5'b00111: data_out_0 = 5'b00111;
            5'b01000: data_out_0 = 5'b01000;
            5'b01001: data_out_0 = 5'b01001;
            5'b01010: data_out_0 = 5'b01010;
            5'b01011: data_out_0 = 5'b01011;
            5'b01100: data_out_0 = 5'b01100;
            5'b01101: data_out_0 = 5'b01101;
            5'b01110: data_out_0 = 5'b01110;
            5'b01111: data_out_0 = 5'b01111;
            5'b10000: data_out_0 = 5'b00000;
            5'b10001: data_out_0 = 5'b00000;
            5'b10010: data_out_0 = 5'b00000;
            5'b10011: data_out_0 = 5'b00000;
            5'b10100: data_out_0 = 5'b00000;
            5'b10101: data_out_0 = 5'b00000;
            5'b10110: data_out_0 = 5'b00000;
            5'b10111: data_out_0 = 5'b00000;
            5'b11000: data_out_0 = 5'b00000;
            5'b11001: data_out_0 = 5'b00000;
            5'b11010: data_out_0 = 5'b00000;
            5'b11011: data_out_0 = 5'b00000;
            5'b11100: data_out_0 = 5'b00000;
            5'b11101: data_out_0 = 5'b00000;
            5'b11110: data_out_0 = 5'b00000;
            5'b11111: data_out_0 = 5'b00000;
            default: data_out_0 = 5'b0;
        endcase
    end
endmodule
