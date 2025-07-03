
`default_nettype wire
`timescale 1 ns / 1 ps

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
// PASTE HERE
//#############################################################################

// layer 0 - myproject_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_33_13_5_3_0_config2_s
localparam integer LAYER_0_NUM_DATA_INPUTS   = 1;
localparam integer LAYER_0_INPUT_DATA_WIDTH  = 16;
localparam integer LAYER_0_NUM_DATA_OUTPUTS  = 2;
localparam integer LAYER_0_OUTPUT_DATA_WIDTH = 33;
wire                                 layer_0_data_in_ready;
wire                                 layer_0_data_out_valid;
wire [LAYER_0_OUTPUT_DATA_WIDTH-1:0] layer_0_data_out [LAYER_0_NUM_DATA_OUTPUTS-1:0];



//#############################################################################


//#############################################################################
// PASTE HERE
//#############################################################################

// global connections with the first layer
assign ap_ready       = layer_0_data_in_ready;

// global connections with the last layer
assign ap_done        = layer_0_data_out_valid;
assign data_out_valid = layer_0_data_out_valid;
assign data_out       = layer_0_data_out;


//#############################################################################


//#############################################################################
// PASTE HERE
//#############################################################################

// layer 0 - myproject_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_33_13_5_3_0_config2_s

wrapper_myproject_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_33_13_5_3_0_config2_s #(
  .CYCLES_TO_WAIT_AFTER_OUTPUT (1),

  .FORCE_LATENCY_CYCLES (0),

  .FORCE_II_CYLES (1),

  .NUM_INPUT_BUFFERS (0),

  .NUM_DATA_INPUTS   (1),
  .INPUT_DATA_WIDTH  (16),

  .NUM_DATA_OUTPUTS  (2),
  .OUTPUT_DATA_WIDTH (33)
)
call_ret_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_33_13_5_3_0_config2_s_fu_50(
  .clk   (ap_clk),
  .rst   (ap_rst),

  .data_in_valid  (global_data_in_valid),
  .data_in        (global_data_in),
  .data_in_ready  (layer_0_data_in_ready),

  .data_out_valid (layer_0_data_out_valid),
  .data_out       (layer_0_data_out),
  .data_out_ready (global_data_out_ready)
);



//#############################################################################




endmodule : neural_network

