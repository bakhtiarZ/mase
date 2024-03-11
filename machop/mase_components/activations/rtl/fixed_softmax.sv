`timescale 1ns / 1ps
module fixed_softmax #(
    /* verilator lint_off UNUSEDPARAM */
    parameter DATA_IN_0_PRECISION_0 = 8,
    parameter DATA_IN_0_PRECISION_1 = 4,
    parameter DATA_IN_0_TENSOR_SIZE_DIM_0 = 10, // input vector size
    parameter DATA_IN_0_TENSOR_SIZE_DIM_1 = 1,  // 
    parameter DATA_IN_0_PARALLELISM_DIM_0 = 1,  // incoming elements -
    parameter DATA_IN_0_PARALLELISM_DIM_1 = 1,  // batch size

    parameter IN_0_DEPTH = DATA_IN_0_TENSOR_SIZE_DIM_0 / DATA_IN_0_PARALLELISM_DIM_0,

    parameter DATA_OUT_0_PRECISION_0 = 8,
    parameter DATA_OUT_0_PRECISION_1 = 4,
    parameter DATA_OUT_0_TENSOR_SIZE_DIM_0 = 10,
    parameter DATA_OUT_0_TENSOR_SIZE_DIM_1 = 1,
    parameter DATA_OUT_0_PARALLELISM_DIM_0 = 1,
    parameter DATA_OUT_0_PARALLELISM_DIM_1 = 1,

    parameter DATA_INTERMEDIATE_0_PRECISION_0 = DATA_OUT_0_PRECISION_0,
    parameter DATA_INTERMEDIATE_0_PRECISION_1 = DATA_OUT_0_PRECISION_1

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

  // softmax over a vector
  // each vector might be split into block of elements
  // Can handle multiple batches at once
  // each iteration recieves a batch of blocks

  split2 #(
  ) input_handshake_split (
    .data_in_valid(data_in_0_valid),
    .data_in_ready(data_in_0_ready),
    .data_out_valid({ff_exp_in_data_valid, summed_in_valid}),
    .data_out_ready({ff_exp_in_data_ready, summed_in_ready[0]})
  );

  localparam MEM_SIZE = (2**(DATA_IN_0_PRECISION_0)); //the threshold
  logic [DATA_INTERMEDIATE_0_PRECISION_0-1:0] exp [MEM_SIZE];

  initial begin
    $readmemb("/workspace/machop/mase_components/activations/rtl/exp_map.mem", exp_data); // change name
  end              //mase/machop/mase_components/activations/rtl/elu_map.mem
  
  logic [DATA_INTERMEDIATE_0_PRECISION_0-1:0] exp_data[DATA_IN_0_PARALLELISM_DIM_0*DATA_IN_0_PARALLELISM_DIM_1-1:0];
  logic [DATA_INTERMEDIATE_0_PRECISION_0-1:0] ff_exp_data[DATA_IN_0_PARALLELISM_DIM_0*DATA_IN_0_PARALLELISM_DIM_1-1:0];
  logic ff_exp_in_data_valid;
  logic ff_exp_in_data_ready;
  logic ff_exp_data_valid;
  logic ff_exp_data_ready;

  for (genvar i = 0; i < DATA_IN_0_PARALLELISM_DIM_0*DATA_IN_0_PARALLELISM_DIM_1; i++) begin : exp_mem_read
    always_comb begin
      exp_data[i] = exp[data_in_0[i]]; // exponential
    end
  end

 // I hope this stores all incoming inputs
  input_buffer #(
    .IN_WIDTH(DATA_INTERMEDIATE_0_PRECISION_0), //bitwdith
    .IN_PARALLELISM(DATA_IN_0_PARALLELISM_DIM_0 * DATA_IN_0_PARALLELISM_DIM_1), // number of inputs - Parallelism DIM0
    .IN_SIZE(1), // number of inputs - Parallelism DIM1

    .BUFFER_SIZE(IN_0_DEPTH), 
    .REPEAT(1),

    .OUT_WIDTH(DATA_INTERMEDIATE_0_PRECISION_0),
    .OUT_PARALLELISM(IN_0_DEPTH * DATA_IN_0_PARALLELISM_DIM_0 * DATA_OUT_0_PARALLELISM_DIM_1),
    .OUT_SIZE(1)
  ) exp_buffer (
    .clk(clk),
    .rst(rst),

    .data_in(exp_data),
    .data_in_valid(ff_exp_in_data_valid), // write enable
    .data_in_ready(data_in_0_ready), // full signal - ready until buffer is buffer ready goes low stopping new inputs

    .data_out(ff_exp_data),
    .data_out_valid(ff_exp_data_valid), // valid read
    .data_out_ready(ff_exp_data_ready) // read enable I think
  );

  localparam SUM_WIDTH = $clog2(DATA_IN_0_PARALLELISM_DIM_0) + DATA_INTERMEDIATE_0_PRECISION_0;
  localparam ACC_WIDTH = $clog2(IN_0_DEPTH) + SUM_WIDTH;


  logic [SUM_WIDTH-1:0] summed_exp_data [DATA_IN_0_PARALLELISM_DIM_1-1:0]; // sum of current block
  logic summed_out_valid [DATA_IN_0_PARALLELISM_DIM_1-1:0];
  logic summed_out_ready [DATA_IN_0_PARALLELISM_DIM_1-1:0];
  logic summed_in_ready [DATA_IN_0_PARALLELISM_DIM_1-1:0];
  logic summed_in_valid;

  logic [ACC_WIDTH-1:0] accumulated_exp_data [DATA_IN_0_PARALLELISM_DIM_1-1:0]; // accumulation of total vector
  logic acc_out_valid [DATA_IN_0_PARALLELISM_DIM_1-1:0];
  logic acc_out_ready;

  for (genvar i = 0; i < DATA_IN_0_PARALLELISM_DIM_1; i++) begin : accumulate_batches
    
    fixed_adder_tree #(
        .IN_SIZE (DATA_IN_0_PARALLELISM_DIM_0),
        .IN_WIDTH(DATA_INTERMEDIATE_0_PRECISION_0)
    ) block_sum (
        .clk(clk),
        .rst(rst),
        .data_in(exp_data[DATA_IN_0_PARALLELISM_DIM_0*i +: DATA_IN_0_PARALLELISM_DIM_0]),
        .data_in_valid(summed_in_valid), // adder enable
        .data_in_ready(summed_in_ready[i]), // addition complete - need to join with the buffer ready and many readys
        .data_out(summed_exp_data[i]), // create a sum variable for the mini set 
        .data_out_valid(summed_out_valid[i]), // sum is valid
        .data_out_ready(summed_out_ready[i]) // next module needs the sum 
    );

    fixed_accumulator #(
        .IN_WIDTH(DATA_IN_0_PRECISION_0),
        .IN_DEPTH(IN_0_DEPTH)
    ) fixed_accumulator_inst (
        .clk(clk),
        .rst(rst),
        .data_in(summed_exp_data[i]), // sum variable for mini set
        .data_in_valid(summed_out_valid[i]), // accumulator enable
        .data_in_ready(summed_out_ready[i]), // accumulator complete
        .data_out(accumulated_exp_data[i]), // accumulated variable
        .data_out_valid(acc_out_valid[i]), //accumulation of ALL variables complete (this is my state machine)
        .data_out_ready(acc_out_ready) // Start the accumulation
    );

  end

  for (genvar i = 0; i < DATA_IN_0_PARALLELISM_DIM_1; i++) begin : scale_batches
    for (genvar j = 0; j < DATA_IN_0_PARALLELISM_DIM_0; j++) begin : div_elements
      always_comb begin
        data_out_0[DATA_IN_0_PARALLELISM_DIM_0*(i) + j] = ff_exp_data[DATA_IN_0_PARALLELISM_DIM_0*(i) + j] / accumulated_exp_data[i];
      end
    end
  end

  join2 #(
  ) output_handshake_split (
    .data_in_valid({ff_exp_data_valid, acc_out_valid[0]}),
    .data_in_ready({ff_exp_data_ready, acc_out_ready}),
    .data_out_valid(data_out_0_valid),
    .data_out_ready(data_out_0_ready)
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

  // assign data_out_0_valid = data_in_0_valid;
  // assign data_in_0_ready  = data_out_0_ready;

endmodule
