`timescale 1ns / 1ps
module fixed_softmax #(
    /* verilator lint_off UNUSEDPARAM */
    parameter DATA_IN_0_PRECISION_0 = 8,
    parameter DATA_IN_0_PRECISION_1 = 4,
    parameter DATA_IN_0_TENSOR_SIZE_DIM_0 = 10, // input vector size
    parameter DATA_IN_0_TENSOR_SIZE_DIM_1 = 1,  // 
    parameter DATA_IN_0_PARALLELISM_DIM_0 = 1,  // incoming elements 
    parameter DATA_IN_0_PARALLELISM_DIM_1 = 1,  // batcch size

    parameter IN_0_DEPTH = DATA_IN_0_TENSOR_SIZE_DIM_0 / DATA_IN_0_PARALLELISM_DIM_0,

    parameter DEP__DATA_OUT_0_PRECISION_0 = DATA_IN_0_PRECISION_0 + WEIGHT_PRECISION_0 + $clog2(
        DATA_IN_0_TENSOR_SIZE_DIM_0
    ) + $clog2(
        IN_0_DEPTH
    ) + HAS_BIAS,
    parameter DEP__DATA_OUT_0_PRECISION_1 = DATA_IN_0_PRECISION_1 + WEIGHT_PRECISION_1,

    parameter DATA_OUT_0_PRECISION_0 = 8,
    parameter DATA_OUT_0_PRECISION_1 = 4,
    parameter DATA_OUT_0_TENSOR_SIZE_DIM_0 = 10,
    parameter DATA_OUT_0_TENSOR_SIZE_DIM_1 = 1,
    parameter DATA_OUT_0_PARALLELISM_DIM_0 = 1,
    parameter DATA_OUT_0_PARALLELISM_DIM_1 = 1

    parameter DATA_INTERMEDIATE_0_PRECISION_0 = DATA_OUT_0_PRECISION_0,
    parameter DATA_INTERMEDIATE_0_PRECISION_1 = DATA_OUT_0_PRECISION_1,

) (
    /* verilator lint_off UNUSEDSIGNAL */
    input rst,
    input clk,
    input logic [DATA_IN_0_PRECISION_0-1:0] data_in_0[DATA_IN_0_PARALLELISM_DIM_0*DATA_IN_0_PARALLELISM_DIM_1-1:0],
    output logic [DATA_OUT_0_PRECISION_0-1:0] data_out_0[DATA_OUT_0_PARALLELISM_DIM_0*DATA_OUT_0_PARALLELISM_DIM_1-1:0],

    input  logic data_in_0_valid,
    output logic data_in_0_ready,
    output logic data_out_0_valid,
    input  logic data_out_0_ready
);
  localparam MEM_SIZE = (2**(DATA_IN_0_PRECISION_0)); //the threshold
  logic [DATA_INTERMEDIATE_0_PRECISION_0-1:0] exp [MEM_SIZE];

  initial begin
    $readmemb("/workspace/machop/mase_components/activations/rtl/exp_map.mem", exp_data); // change name
  end              //mase/machop/mase_components/activations/rtl/elu_map.mem
  
  logic [DATA_INTERMEDIATE_0_PRECISION_0-1:0] exp_data[DATA_IN_0_PARALLELISM_DIM_0*DATA_IN_0_PARALLELISM_DIM_1-1:0];
  logic [DATA_INTERMEDIATE_0_PRECISION_0-1:0] ff_exp_data[DATA_IN_0_PARALLELISM_DIM_0*DATA_IN_0_PARALLELISM_DIM_1-1:0];
  logic ff_exp_data_valid;
  logic ff_exp_data_ready;

  for (genvar i = 0; i < DATA_IN_0_PARALLELISM_DIM_0*DATA_IN_0_PARALLELISM_DIM_1; i++) begin : elu
    always_comb begin
      exp_data[i] = exp[data_in_0[i]]; // exponential
    end
  end

  // naive implementation stores in FIFO then computes

 // I hope this stores all incoming inputs
input_buffer #(
  .IN_WIDTH(DATA_IN_0_PRECISION_0), //bitwdith
  .IN_PARALLELISM(DATA_IN_0_PARALLELISM_DIM_0 * DATA_IN_0_PARALLELISM_DIM_1), // number of inputs - Parallelism DIM0
  .IN_SIZE(1), // number of inputs - Parallelism DIM1

  .BUFFER_SIZE(IN_0_DEPTH), 
  .REPEAT(1),

  .OUT_WIDTH(),
  .OUT_PARALLELISM(IN_0_DEPTH * DATA_IN_0_PARALLELISM_DIM_0 * DATA_OUT_0_PARALLELISM_DIM_1),
  .OUT_SIZE(1),
) exp_buffer (
  .clk(clk),
  .rst(rst),

  .data_in(exp_data),
  .data_in_valid(____) // write enable
  .data_in_ready(____) // full signal

  .data_out(ff_exp_data),
  .data_out_valid(___), // valid read
  .data_out_ready(___), // read enable I think
)

fixed_adder_tree #(
    .IN_SIZE (DATA_IN_0_PARALLELISM_DIM_0*DATA_IN_0_PARALLELISM_DIM_1),
    .IN_WIDTH(DATA_INTERMEDIATE_0_PRECISION_0)
) block_sum (
    .data_in(exp_data),
    .data_in_valid(____), // adder enable
    .data_in_ready(____), // addition complete
    .data_out(_____), // create a sum variable for the mini set 
    .data_out_valid(____), // sum is valid
    .data_out_ready(____), // next module needs the sum 
);

fixed_accumulator #(
    .IN_WIDTH(DATA_IN_0_PRECISION_0),
    .IN_DEPTH(IN_0_DEPTH)
) fixed_accumulator_inst (
    .clk(clk),
    .rst(rst),
    .data_in(_____), // sum variable for mini set
    .data_in_valid(_____), // accumulator enable
    .data_in_ready(______), // accumulator complete
    .data_out(_____), // accumulated variable
    .data_out_valid(______), //accumulation of ALL variables complete (this is my state machine)
    .data_out_ready(_____), // Start the accumulation
);







  // always_comb begin
  //   $display("MEM SIZE %d", MEM_SIZE);
  //   $display("--------------------------------DATA IN VALID: %b", data_in_0_valid);
  //   if(data_in_0_valid) begin
  //     data_out_0[0] = elu_data[(data_in_0[0])];
  //     $display("--------------------------------DATA IN 0: %b", data_in_0[0]);
  //     $display("--------------------------------DATA OUT 0: %b", data_out_0[0]);
  //     $display("--------------------------------ELU DATA of INP: %b", elu_data['b11111]);

  //     $display("\n\n");
  //     $display("--------------------------------elu data\n%p " , elu_data);
  //   end
  // end

  assign data_out_0_valid = data_in_0_valid;
  assign data_in_0_ready  = data_out_0_ready;

endmodule
