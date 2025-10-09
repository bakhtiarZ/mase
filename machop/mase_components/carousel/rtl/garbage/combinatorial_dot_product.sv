module combinatorial_dot_product #(
    parameter DATA_WIDTH = 16,
    parameter INPUT_SIZE = 8
) (
    input  logic [DATA_WIDTH-1:0]    data_in [INPUT_SIZE],
    input  logic                     data_in_valid,
    output logic                     data_in_ready,
    
    output logic [2*DATA_WIDTH-1:0]  data_out
    output logic                     data_out_valid,
    input  logic                     data_out_ready,
    
    input  logic [DATA_WIDTH-1:0]    weights [INPUT_SIZE],
    input  logic                     data_in_valid,
    output logic                     data_in_ready,
    
);

    logic [2*DATA_WIDTH-1:0] partial_products [INPUT_SIZE];

    // Compute partial products
    genvar i;
    generate
        for (i = 0; i < INPUT_SIZE; i++) begin
            always_comb begin
                partial_products[i] = inputs[i] * weights[i];
            end
        end
    endgenerate

    // Sum up all partial products
    integer j;
    always_comb begin
        dot_product = 0;
        for (j = 0; j < INPUT_SIZE; j++) begin
            dot_product += partial_products[j];
        end
    end

endmodule