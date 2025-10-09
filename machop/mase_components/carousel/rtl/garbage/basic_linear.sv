module basic_linear #(
    parameter int WIDTH = 8,
    parameter int PACKED_WIDTH = 8 * 3,
    parameter int BUFFER_SIZE = 1,
    parameter int dummy=0,
) (
    input  logic [PACKED_WIDTH-1:0]         data_in      [BUFFER_SIZE],
    input  logic                            data_in_valid[BUFFER_SIZE],
    output logic                            data_in_ready[BUFFER_SIZE],
    output logic [PACKED_WIDTH-1:0]         data_out     [BUFFER_SIZE],
    output logic                            data_out_valid[BUFFER_SIZE],
    input  logic                            data_out_ready[BUFFER_SIZE],

    input  logic clk,
    input  logic rst 
);

  logic [PACKED_WIDTH-1:0] carousel_out [BUFFER_SIZE];
  logic             carousel_out_valid [BUFFER_SIZE];
  logic             carousel_out_ready [BUFFER_SIZE];

  // Input Carousel instantiation
  carousel_core_always_shift #(
    .WIDTH(PACKED_WIDTH),
    .BUFFER_SIZE(BUFFER_SIZE)
  ) core_inst (
    .data_in       (data_in),
    .data_in_valid (data_in_valid),
    .data_in_ready (data_in_ready),
    .data_out      (carousel_out),
    .data_out_valid(carousel_out_valid),
    .data_out_ready(carousel_out_ready),
    .clk           (clk),
    .rst           (rst)
  );

  // Single PE
  localparam INPUT_SIZE = PACKED_WIDTH / WIDTH;
  logic [WIDTH-1:0] unpacked_weights [INPUT_SIZE];

  always_comb begin
    for (int i = 0; i < INPUT_SIZE; i++) begin
      unpacked_weights[i] = carousel_out[0][(i+1)*WIDTH-1 -: WIDTH];
    end
  end

  logic [WIDTH-1:0] fixed_input [INPUT_SIZE-1:0];
  logic fixed_input_valid;
  logic fixed_input_ready;
  assign fixed_input_valid = 1;
  always_comb begin
    for (int i = 0; i < INPUT_SIZE; i++) begin
      fixed_input[i] = i + 1;
    end
  end

  logic [WIDTH-1:0] linear_data_out [INPUT_SIZE-1:0];
  logic             linear_data_out_valid;
  logic             linear_data_out_ready;

  assign linear_data_out_ready = 1; // Always ready to accept data

  combinatorial_dot_product #(
    .INPUT_SIZE(INPUT_SIZE),
    .DATA_WIDTH(WIDTH)
  ) linear_inst (
    .data_in(fixed_input),
    .data_in_valid(fixed_input_valid),
    .data_in_ready(fixed_input_ready),
    .weights_in(unpacked_weights),
    .weights_in_valid(carousel_out_valid),
    .weights_in_ready(carousel_out_ready),
    .data_out(linear_data_out),
    .data_out_valid(linear_data_out_valid),
    .data_out_ready(linear_data_out_ready)
  );

  // Register bank to store data_out
  logic [WIDTH-1:0] register_bank [INPUT_SIZE-1:0];
  logic [$clog2(INPUT_SIZE)-1:0] store_pointer;
  logic                          store_valid;

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      store_pointer <= 0;
      store_valid <= 0;
    end else begin
      if (linear_data_out_valid) begin
        register_bank[store_pointer] <= linear_data_out[WIDTH-1:0];
        store_pointer <= (store_pointer + 1) % INPUT_SIZE;
        store_valid <= 1;
      end else begin
        store_valid <= 0;
      end
    end
  end
  
  assign data_out = register_bank;
  assign data_out_valid = store_valid;

endmodule