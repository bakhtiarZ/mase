/*


*/

`default_nettype wire
`timescale 1 ns / 1 ps

/*
module neural_network (

  input  ap_clk,
  input  ap_rst,
  input  ap_start,
  output ap_done,
  output ap_idle,
  output ap_ready,

  input  [255:0] fc1_input_V,
  input          fc1_input_V_ap_vld,
  output [ 15:0] layer13_out_0_V,
  output         layer13_out_0_V_ap_vld,
  output [ 15:0] layer13_out_1_V,
  output         layer13_out_1_V_ap_vld,
  output [ 15:0] layer13_out_2_V,
  output         layer13_out_2_V_ap_vld,
  output [ 15:0] layer13_out_3_V,
  output         layer13_out_3_V_ap_vld,
  output [ 15:0] layer13_out_4_V,
  output         layer13_out_4_V_ap_vld,
  output [ 15:0] const_size_in_1,
  output         const_size_in_1_ap_vld,
  output [ 15:0] const_size_out_1,
  output         const_size_out_1_ap_vld
);
*/

module neural_network #(
  NUM_DATA_INPUTS   = 0,
  INPUT_DATA_WIDTH  = 0,

  NUM_DATA_OUTPUTS  = 0,
  OUTPUT_DATA_WIDTH = 0
)(

  input  ap_clk,
  input  ap_rst,
  input  ap_start,
  output ap_done,
  output ap_idle,
  output ap_ready,

  input                          data_in_valid,
  input  [INPUT_DATA_WIDTH-1:0]  data_in [NUM_DATA_INPUTS-1:0],

  output                         data_out_valid,
  output [OUTPUT_DATA_WIDTH-1:0] data_out [NUM_DATA_OUTPUTS-1:0]
);


// global data signals
wire                        global_data_in_valid;
wire [INPUT_DATA_WIDTH-1:0] global_data_in  [NUM_DATA_INPUTS-1:0];
reg                         global_data_out_ready;

// set global signal values so we have a consistent connection scheme
assign global_data_in_valid  = ap_start & data_in_valid;
assign global_data_in        = data_in;
assign global_data_out_ready = 1'b1;


//#############################################################################
// activity tracker
//#############################################################################

// track the number of inputs we are processing
//  -should be (about) equal to the number of layers
localparam integer MAX_COUNTER_STATES = 256;
localparam integer COUNTER_WIDTH      = $clog2(MAX_COUNTER_STATES);

reg [COUNTER_WIDTH-1:0] input_counter = 0;

// network is idle when:
//  -in the idle state, i.e., not processing anything
//  -not getting new data
assign ap_idle = activity_state == IDLE & ~(global_data_in_valid & layer_0_data_in_ready);

// activity states
typedef enum {IDLE, PROCESSING} activity_state_t;

// activity state machine
activity_state_t activity_state;

always @(posedge ap_clk) begin

  if (ap_rst) begin
    activity_state <= IDLE;
    input_counter  <= 0;

  end
  else begin

    case (activity_state)

      IDLE: begin

        // if we start processing
        if (global_data_in_valid & layer_0_data_in_ready) begin
          activity_state <= PROCESSING;
          input_counter  <= input_counter + 1;
        end

      end
      PROCESSING: begin

        // if we start processing new data AND we output data
        if (global_data_in_valid & layer_0_data_in_ready & data_out_valid) begin
          // no change to counter
          // no change to state
        end

        // if we start processing new data
        else if (global_data_in_valid & layer_0_data_in_ready) begin
          input_counter <= input_counter + 1;
        end

        // if we output data
        else if (data_out_valid) begin

          input_counter <= input_counter - 1;

          // if there is no more data being processed
          if (input_counter == 1) begin
            activity_state <= IDLE;
          end

        end
      end

      // default
      default:
        activity_state <= IDLE;
    endcase
  end
end

//#############################################################################

/*
// global connections with the first layer
assign ap_ready       = layer_0_data_in_ready & stall_counter == 0;


localparam integer MAXIMUM_NUMBER_OF_STALL_CYCLES       = 64;
localparam integer MAXIMUM_NUMBER_OF_STALL_CYCLES_WIDTH = $clog2(MAXIMUM_NUMBER_OF_STALL_CYCLES+1);

reg [MAXIMUM_NUMBER_OF_STALL_CYCLES_WIDTH-1:0] stall_counter = 0;

wire stall_detected;

// states
//typedef enum {STALL_IDLE, STALL_WAIT} stall_state_t;

// state machine
//stall_state_t stall_state;


assign stall_detected = (layer_0_data_out_valid & ~layer_1_data_in_ready)
					  | (layer_1_data_out_valid & ~layer_2_data_in_ready)
					  | (layer_2_data_out_valid & ~layer_3_data_in_ready)
					  | (layer_3_data_out_valid & ~layer_4_data_in_ready)
					  | (layer_4_data_out_valid & ~layer_5_data_in_ready)
					  | (layer_5_data_out_valid & ~layer_6_data_in_ready)
					  | (layer_6_data_out_valid & ~layer_7_data_in_ready)
					  | (layer_7_data_out_valid & ~global_data_out_ready);


always @(posedge ap_clk) begin

  // if the stall count should increase AND decrease
  if (stall_detected & layer_0_data_in_ready) begin
	// do nothing
  end

  // else, if the stall count should increase
  else if (stall_detected) begin
	stall_counter <= stall_counter + 1;
  end

  // else, if the stall count should decrease
  else if (layer_0_data_in_ready & stall_counter != 0) begin
	stall_counter <= stall_counter - 1;
  end
end

##################################################################
// layer 0 - dense_latency_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_2
wrapper_dense_latency_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_2 #(
  .CYCLES_TO_WAIT_AFTER_OUTPUT (1),

  .NUM_DATA_INPUTS   (1),
  .INPUT_DATA_WIDTH  (256),

  .NUM_DATA_OUTPUTS  (16),
  .OUTPUT_DATA_WIDTH (16)
)
layer_0(
  .clk   (ap_clk),
  .rst   (ap_rst),

  .data_in_valid  (global_data_in_valid & stall_counter == 0),
*/



//#############################################################################
// PASTE HERE
//#############################################################################

// layer 0 - myproject_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s
localparam integer LAYER_0_NUM_DATA_INPUTS   = 2;
localparam integer LAYER_0_INPUT_DATA_WIDTH  = 16;
localparam integer LAYER_0_NUM_DATA_OUTPUTS  = 10;
localparam integer LAYER_0_OUTPUT_DATA_WIDTH = 16;
wire                                 layer_0_data_in_ready;
wire                                 layer_0_data_out_valid;
wire [LAYER_0_OUTPUT_DATA_WIDTH-1:0] layer_0_data_out [LAYER_0_NUM_DATA_OUTPUTS-1:0];

// layer 1 - myproject_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s
localparam integer LAYER_1_NUM_DATA_INPUTS   = 10;
localparam integer LAYER_1_INPUT_DATA_WIDTH  = 16;
localparam integer LAYER_1_NUM_DATA_OUTPUTS  = 10;
localparam integer LAYER_1_OUTPUT_DATA_WIDTH = 16;
wire                                 layer_1_data_in_ready;
wire                                 layer_1_data_out_valid;
wire [LAYER_1_OUTPUT_DATA_WIDTH-1:0] layer_1_data_out [LAYER_1_NUM_DATA_OUTPUTS-1:0];

// layer 2 - myproject_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config4_s
localparam integer LAYER_2_NUM_DATA_INPUTS   = 10;
localparam integer LAYER_2_INPUT_DATA_WIDTH  = 16;
localparam integer LAYER_2_NUM_DATA_OUTPUTS  = 1;
localparam integer LAYER_2_OUTPUT_DATA_WIDTH = 16;
wire                                 layer_2_data_in_ready;
wire                                 layer_2_data_out_valid;
wire [LAYER_2_OUTPUT_DATA_WIDTH-1:0] layer_2_data_out [LAYER_2_NUM_DATA_OUTPUTS-1:0];

// layer 3 - myproject_sigmoid_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_sigmoid_config5_s
localparam integer LAYER_3_NUM_DATA_INPUTS   = 1;
localparam integer LAYER_3_INPUT_DATA_WIDTH  = 16;
localparam integer LAYER_3_NUM_DATA_OUTPUTS  = 1;
localparam integer LAYER_3_OUTPUT_DATA_WIDTH = 10;
wire                                 layer_3_data_in_ready;
wire                                 layer_3_data_out_valid;
wire [LAYER_3_OUTPUT_DATA_WIDTH-1:0] layer_3_data_out [LAYER_3_NUM_DATA_OUTPUTS-1:0];



//#############################################################################


//#############################################################################
// PASTE HERE
//#############################################################################

// global connections with the first layer
assign ap_ready       = layer_0_data_in_ready;

// global connections with the last layer
assign ap_done        = layer_3_data_out_valid;
assign data_out_valid = layer_3_data_out_valid;
assign data_out       = layer_3_data_out;


//#############################################################################


//#############################################################################
// PASTE HERE
//#############################################################################

// layer 0 - myproject_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s

wrapper_myproject_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s #(
  .CYCLES_TO_WAIT_AFTER_OUTPUT (0),

  .FORCE_LATENCY_CYCLES (6),

  .FORCE_II_CYLES (5),

  .NUM_INPUT_BUFFERS (0),

  .NUM_DATA_INPUTS   (2),
  .INPUT_DATA_WIDTH  (16),

  .NUM_DATA_OUTPUTS  (10),
  .OUTPUT_DATA_WIDTH (16)
)
grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45(
  .clk   (ap_clk),
  .rst   (ap_rst),

  .data_in_valid  (global_data_in_valid),
  .data_in        (global_data_in),
  .data_in_ready  (layer_0_data_in_ready),

  .data_out_valid (layer_0_data_out_valid),
  .data_out       (layer_0_data_out),
  .data_out_ready (layer_1_data_in_ready)
);

// layer 1 - myproject_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s

wrapper_myproject_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s #(
  .NUM_COMPUTE_POOLS (1),

  .NUM_DATA_INPUTS   (10),
  .INPUT_DATA_WIDTH  (16),

  .NUM_DATA_OUTPUTS  (10),
  .OUTPUT_DATA_WIDTH (16),

  .INTERMEDIATE_REGS (0),
  .OUTPUT_REGISTERS  (0),
  .MODE              ("cascade")
)
grp_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_fu_51(
  .clk   (ap_clk),
  .rst   (ap_rst),

  .data_in_valid  (layer_0_data_out_valid),
  .data_in        (layer_0_data_out),
  .data_in_ready  (layer_1_data_in_ready),

  .data_out_valid (layer_1_data_out_valid),
  .data_out       (layer_1_data_out),
  .data_out_ready (layer_2_data_in_ready)
);

// layer 2 - myproject_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config4_s

wrapper_myproject_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config4_s #(
  .CYCLES_TO_WAIT_AFTER_OUTPUT (0),

  .FORCE_LATENCY_CYCLES (1),

  .FORCE_II_CYLES (1),

  .NUM_INPUT_BUFFERS (0),

  .NUM_DATA_INPUTS   (10),
  .INPUT_DATA_WIDTH  (16),

  .NUM_DATA_OUTPUTS  (1),
  .OUTPUT_DATA_WIDTH (16)
)
grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config4_s_fu_67(
  .clk   (ap_clk),
  .rst   (ap_rst),

  .data_in_valid  (layer_1_data_out_valid),
  .data_in        (layer_1_data_out),
  .data_in_ready  (layer_2_data_in_ready),

  .data_out_valid (layer_2_data_out_valid),
  .data_out       (layer_2_data_out),
  .data_out_ready (layer_3_data_in_ready)
);

// layer 3 - myproject_sigmoid_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_sigmoid_config5_s

wrapper_myproject_sigmoid_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_sigmoid_config5_s #(
  .CYCLES_TO_WAIT_AFTER_OUTPUT (0),

  .FORCE_LATENCY_CYCLES (2),

  .FORCE_II_CYLES (1),

  .NUM_INPUT_BUFFERS (0),

  .NUM_DATA_INPUTS   (1),
  .INPUT_DATA_WIDTH  (16),

  .NUM_DATA_OUTPUTS  (1),
  .OUTPUT_DATA_WIDTH (10)
)
grp_sigmoid_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_sigmoid_config5_s_fu_81(
  .clk   (ap_clk),
  .rst   (ap_rst),

  .data_in_valid  (layer_2_data_out_valid),
  .data_in        (layer_2_data_out),
  .data_in_ready  (layer_3_data_in_ready),

  .data_out_valid (layer_3_data_out_valid),
  .data_out       (layer_3_data_out),
  .data_out_ready (global_data_out_ready)
);



//#############################################################################




endmodule : neural_network

