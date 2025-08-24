`timescale 1ns / 1ps
module mysetup #(
    // parameters
    parameter int DATA_WIDTH = 8,
    parameter int INPUT_SIZE = 4,
    parameter int OUT_SIZE = 2,
    parameter int OUT_WIDTH = DATA_WIDTH + DATA_WIDTH + $clog2(INPUT_SIZE)
) (
    // ports
    input  logic clk,
    input  logic rst,

    output logic [OUT_WIDTH-1:0] data_out [OUT_SIZE],
    output logic                               data_out_valid[OUT_SIZE]
);

logic [DATA_WIDTH * INPUT_SIZE-1:0] initial_weights [OUT_SIZE];
logic  initial_weights_valid [OUT_SIZE];
initial begin
    // mega hard coding them
    initial_weights[0] = 32'h00000403;
    initial_weights[1] = 32'h00000201;
    for (int i=0; i<OUT_SIZE; i++) begin
        initial_weights_valid[i] = 1'b1;
    end
    x_value = 32'h0101;
    x_value_valid = 1;
    // turn of all slots except the first
    for (int i=0; i<OUT_SIZE; i++) begin
        pe_array_ready[i] = 0; 
    end
    pe_array_ready[0] = 1;
end

// each carousel slot needs to hold 4 values, so its packed
logic [DATA_WIDTH * INPUT_SIZE-1:0] carousel_out [OUT_SIZE];
logic carousel_out_valid [OUT_SIZE];
logic carousel_out_ready [OUT_SIZE];
logic dummy [OUT_SIZE];
carousel_core_always_shift  #(
    .WIDTH(DATA_WIDTH*INPUT_SIZE),
    .BUFFER_SIZE(OUT_SIZE)
    // fill in other parameters
) carousel_inst (
    .clk,
    .rst,
    .data_in(initial_weights),
    .data_in_valid(initial_weights_valid),
    .data_in_ready(dummy), //unconnected
    .data_out(carousel_out),
    .data_out_valid(carousel_out_valid),
    .data_out_ready(carousel_out_ready)
);

logic pe_array_ready [OUT_SIZE];

// need to unpack the x_values, and also the weights
logic [DATA_WIDTH-1:0] unpacked_weight [OUT_SIZE][INPUT_SIZE];
always_comb begin : unpack_weights
    for(int i=0; i<OUT_SIZE; i++) begin
        for (int j=0; j<INPUT_SIZE ; j++) begin
            unpacked_weight[i][j] = carousel_out[i][DATA_WIDTH*(j+1)-1 -: DATA_WIDTH];
        end
    end
end


logic [DATA_WIDTH * INPUT_SIZE - 1 :0] x_value; 
logic x_value_valid ; 
logic x_value_ready ; 
initial begin
    
end

logic [DATA_WIDTH-1:0] unpacked_x [INPUT_SIZE];
always_comb begin : unpack_x
    for (int i=0; i<INPUT_SIZE; i++) begin
        unpacked_x[i] = x_value[DATA_WIDTH*(i+1)-1 -: DATA_WIDTH];
    end
end

fixed_dot_product #(
    .IN_WIDTH(DATA_WIDTH),
    .IN_SIZE(INPUT_SIZE),
    .WEIGHT_WIDTH(DATA_WIDTH)
) mac_inst (
    .clk,
    .rst,
    .data_in(unpacked_x),
    .data_in_valid(x_value_valid),
    .data_in_ready(x_value_ready),
    .weight(unpacked_weight[0]),
    .weight_valid(carousel_out_valid[0]),
    .weight_ready(carousel_out_ready[0]),
    .data_out(pe_out[0]),
    .data_out_valid(pe_out_valid[0]),
    .data_out_ready(pe_out_ready[0])
);
logic [OUT_WIDTH-1:0] pe_out [OUT_SIZE];
logic                 pe_out_ready [OUT_SIZE];
logic                 pe_out_valid [OUT_SIZE];
assign pe_out_ready[0] = 1'b1;

// need to pack pe_0

// always_comb begin : pack_pe_output
//     for (int i = 0; i<OUT_SIZE; i++) begin
//         data_out[(OUT_WIDTH * i) - 1 -: OUT_WIDTH] = pe_out[i];
//     end
// end
always_ff @(posedge clk) begin
    for (int i = 0; i < OUT_SIZE; i++) begin
        if (data_out_valid[i]) begin
            $display("data_out[%0d] = %0d", i, data_out[i]);
        end
    end
end
assign data_out = pe_out;
assign data_out_valid = pe_out_valid;

// with weights of h00000004, and h00000002, we should get output valid with 5 and 3.
    
    
endmodule