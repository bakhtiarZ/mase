module carousel_flatten #(
    parameter int WIDTH = 8,
    parameter int BUFFER_SIZE = 3
) (
    //data ports
    input logic [WIDTH - 1 : 0] data_in_0,
    output logic [WIDTH - 1 : 0] data_out_0,
    input logic  data_in_valid_0,
    output logic data_in_ready_0,
    input logic data_out_ready_0,
    output logic data_out_valid_0,
    input logic [WIDTH - 1 : 0] data_in_1,
    output logic [WIDTH - 1 : 0] data_out_1,
    input logic  data_in_valid_1,
    output logic data_in_ready_1,
    input logic data_out_ready_1,
    output logic data_out_valid_1,
    input logic [WIDTH - 1 : 0] data_in_2,
    output logic [WIDTH - 1 : 0] data_out_2,
    input logic  data_in_valid_2,
    output logic data_in_ready_2,
    input logic data_out_ready_2,
    output logic data_out_valid_2,

    input logic clk,
    input logic rst
);

  // Arrays to connect
  logic [WIDTH-1:0]        data_in      [BUFFER_SIZE];
  logic                    data_in_valid[BUFFER_SIZE];
  logic                    data_in_ready[BUFFER_SIZE];
  logic [WIDTH-1:0]        data_out     [BUFFER_SIZE];
  logic                    data_out_valid[BUFFER_SIZE];
  logic                    data_out_ready[BUFFER_SIZE];

  // Flat-to-array assignments
  assign data_in[0]   = data_in_0;
  assign data_in_valid[0] = data_in_valid_0;
  assign data_out_ready[0]= data_out_ready_0;
  assign data_in[1]   = data_in_1;
  assign data_in_valid[1] = data_in_valid_1;
  assign data_out_ready[1]= data_out_ready_1;
  assign data_in[2]   = data_in_2;
  assign data_in_valid[2] = data_in_valid_2;
  assign data_out_ready[2]= data_out_ready_2;

  // Core instantiation
  carousel_core #(
    .WIDTH(WIDTH),
    .BUFFER_SIZE(BUFFER_SIZE)
  ) core_inst (
    .data_in       (data_in),
    .data_in_valid (data_in_valid),
    .data_in_ready (data_in_ready),
    .data_out      (data_out),
    .data_out_valid(data_out_valid),
    .data_out_ready(data_out_ready),
    .clk           (clk),
    .rst           (rst)
  );

  // Array-to-flat assignments
  // Flat-to-array assignments
  assign data_in_ready_0   = data_in_ready[0];
  assign data_out_0       = data_out[0];
  assign data_out_valid_0  = data_out_valid[0];
  assign data_in_ready_1   = data_in_ready[1];
  assign data_out_1       = data_out[1];
  assign data_out_valid_1  = data_out_valid[1];
  assign data_in_ready_2   = data_in_ready[2];
  assign data_out_2       = data_out[2];
  assign data_out_valid_2  = data_out_valid[2];
endmodule