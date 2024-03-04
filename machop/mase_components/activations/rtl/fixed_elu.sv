`timescale 1ns / 1ps
module fixed_elu #(
    /* verilator lint_off UNUSEDPARAM */
    parameter DATA_IN_0_PRECISION_0 = 8,
    parameter DATA_IN_0_PRECISION_1 = 4,
    parameter DATA_IN_0_TENSOR_SIZE_DIM_0 = 10,
    parameter DATA_IN_0_TENSOR_SIZE_DIM_1 = 1,
    parameter DATA_IN_0_PARALLELISM_DIM_0 = 1,
    parameter DATA_IN_0_PARALLELISM_DIM_1 = 1,

    parameter DATA_OUT_0_PRECISION_0 = 8,
    parameter DATA_OUT_0_PRECISION_1 = 4,
    parameter DATA_OUT_0_TENSOR_SIZE_DIM_0 = 10,
    parameter DATA_OUT_0_TENSOR_SIZE_DIM_1 = 1,
    parameter DATA_OUT_0_PARALLELISM_DIM_0 = 1,
    parameter DATA_OUT_0_PARALLELISM_DIM_1 = 1

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
  logic [DATA_OUT_0_PRECISION_0-1:0] elu_data [MEM_SIZE];

  initial begin
    $readmemb("/workspace/machop/mase_components/activations/rtl/elu_map.mem", elu_data);
  end              //mase/machop/mase_components/activations/rtl/elu_map.mem
  
  for (genvar i = 0; i < DATA_IN_0_PARALLELISM_DIM_0*DATA_IN_0_PARALLELISM_DIM_1; i++) begin : elu
    always_comb begin
      data_out_0[i] = elu_data[data_in_0[i]];
    end
  end

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
