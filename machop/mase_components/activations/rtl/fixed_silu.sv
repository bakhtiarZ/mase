`timescale 1ns / 1ps
module fixed_silu #(
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
  localparam MEM_SIZE = $rtoi(2**(DATA_IN_0_PRECISION_0)); //the threshold
  logic [DATA_OUT_0_PRECISION_0-1:0] silu_data [MEM_SIZE];
  initial begin
    $readmemb("/workspace/machop/mase_components/activations/rtl/silu_map.mem", silu_data);
  end
  for (genvar i = 0; i < DATA_IN_0_PARALLELISM_DIM_0*DATA_IN_0_PARALLELISM_DIM_1; i++) begin : SiLU
    always_comb begin
      data_out_0[i] = silu_data[data_in_0[i]];
    end
  end
  assign data_out_0_valid = data_in_0_valid;
  assign data_in_0_ready  = data_out_0_ready;

endmodule
