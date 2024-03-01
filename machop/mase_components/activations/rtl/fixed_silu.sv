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
    parameter DATA_OUT_0_PARALLELISM_DIM_1 = 1,
    parameter LAMBDA = 0.5, //the threshold
    parameter FX_LAMBDA = $rtoi(LAMBDA * 2**(DATA_IN_0_PRECISION_1)), //the threshold

    parameter INPLACE = 0
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
  logic [DATA_IN_0_PRECISION_0-1:0] silu_data [256];

  // for (genvar i = 0; i < DATA_IN_0_PARALLELISM_DIM_0*DATA_IN_0_PARALLELISM_DIM_1; i++) begin : ReLU
  //   always_comb begin
  //     if ($signed(data_in_0[i]) < -1*FX_LAMBDA) cast_data[i] = data_in_0[i];
  //     else if($signed(data_in_0[i]) > FX_LAMBDA ) cast_data[i] = data_in_0[i];
  //     else cast_data[i] = '0;
  //     $display("%d", cast_data[i]);
  //   end
  // end
  logic [DATA_IN_0_PRECISION_0-1:0] realaddr[DATA_IN_0_PARALLELISM_DIM_0*DATA_IN_0_PARALLELISM_DIM_1-1:0];
  
  initial begin
    $readmemb("/workspace/machop/mase_components/activations/rtl/silu_map.mem", silu_data);
    // $display("input %b %d", data_in_0, data_in_0);
    // $display("realaddr %b %d", realaddr[0], realaddr[0]);
    // $display("SILU at 3 %b", silu_lut[realaddr]);
    // $writememb("/workspace/machop/mase_components/activations/rtl/memory_binary.txt", silu_lut);
  end
  for (genvar i = 0; i < DATA_IN_0_PARALLELISM_DIM_0*DATA_IN_0_PARALLELISM_DIM_1; i++) begin : SiLU
    always_comb begin
      realaddr[i] = $signed(data_in_0[i]) + 128;
      data_out_0[i] = silu_data[realaddr[i]];
    end
  end
  assign data_out_0 = data_in_0;
  assign data_out_0_valid = data_in_0_valid;
  assign data_in_0_ready  = data_out_0_ready;

endmodule
