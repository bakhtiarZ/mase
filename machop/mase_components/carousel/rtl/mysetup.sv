module mysetup #(
    // parameters
    parameter int DATA_WIDTH = 8,
    parameter int INPUT_SIZE = 4,
    parameter int OUTPUT_SIZE = 2
) (
    // ports
    input  logic clk,
    input  logic rst,

    output logic [DATA_WIDTH * INPUT_SIZE : 0]        data_out,
    output logic                    data_out_valid[OUTPUT_SIZE]
);

/*
Constraints:
    nn: 4,2 shape, the 1st dim represents the number of weights in a single carousel slot, the 2nd represents the required slots
*/
logic [DATA_WIDTH * INPUT_SIZE-1:0] initial_weights [OUTPUT_SIZE];
logic  initial_weights_valid [OUTPUT_SIZE];
initial begin
    // mega hard coding them
    initial_weights[0] = 8'h00000004;
    initial_weights[1] = 8'h00000002;
    for (int i=0; i<OUTPUT_SIZE; i++) begin
        initial_weights_valid[i] = 1'b1;
    end
end

// each carousel slot needs to hold 4 values, so its packed
logic [DATA_WIDTH * INPUT_SIZE-1:0] carousel_out [OUTPUT_SIZE];
logic carousel_out_valid [OUTPUT_SIZE];
logic carousel_out_ready [OUTPUT_SIZE];
logic dummy [OUTPUT_SIZE];
carousel_core_always_shift  #(
    .WIDTH(DATA_WIDTH*INPUT_SIZE),
    .BUFFER_SIZE(OUTPUT_SIZE)
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

logic pe_array_ready [INPUT_SIZE];
logic pe_out_valid [INPUT_SIZE];
initial begin
    // turn of all slots except the first
    for (int i=0; i<INPUT_SIZE; i++) begin
        pe_array_ready[i] = 0; 
    end
    pe_array_ready[0] = 1;
end

logic [DATA_WIDTH * INPUT_SIZE - 1 :0] x_value ; 
initial begin
    x_value = 32'h1;
end
logic [DATA_WIDTH * INPUT_SIZE :0] pe_out;
always_comb begin 
    if (carousel_out_valid[0]) begin // only first slot valid
        pe_out = carousel_out[0] + x_value; // should just be the thing + 1
        pe_out_valid[0] = 1'b1;
    end
end

assign data_out = pe_out;
assign data_out_valid = pe_out_valid;

// with weights of h00000004, and h00000002, we should get output valid with 5 and 3.
    
endmodule