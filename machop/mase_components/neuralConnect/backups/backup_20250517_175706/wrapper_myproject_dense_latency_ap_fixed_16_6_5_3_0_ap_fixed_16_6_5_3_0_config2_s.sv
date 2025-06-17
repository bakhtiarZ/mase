/*

Wrapper around a layer, converting the ap_* control signal format to a
valid/ready handshake. The output data is also buffered, and new input data
is stalled when the output is not ready.

*/

`default_nettype wire
`timescale 1ps / 1ps


//DOLLARSIGN--wrapperName
module wrapper_myproject_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s #(

  // account for interval being longer than latency
  //  -i.e., we need to wait X cycles after an output before accepting a new input
  // for 0-cycle oeprations, a value of 0 is treated as 1, as otherwise this
  // would mean infinite processing...
  CYCLES_TO_WAIT_AFTER_OUTPUT = 0,

  // output the data X cycles after it has been input
  //  -value of -1 disables this feature
  FORCE_LATENCY_CYCLES = -1,

  // allow inputs X cycles after the previous input
  //  -value of -1 disables this feature
  FORCE_II_CYLES = -1,

  // number of buffer stages at the input
  NUM_INPUT_BUFFERS = 0,

  // input data parameters
  NUM_DATA_INPUTS   = 0,
  INPUT_DATA_WIDTH  = 0,

  // output data parameters
  NUM_DATA_OUTPUTS  = 0,
  OUTPUT_DATA_WIDTH = 0
)(

  input clk,
  input rst,

  input                          data_in_valid,
  input  [INPUT_DATA_WIDTH-1:0]  data_in  [NUM_DATA_INPUTS-1:0],
  output                         data_in_ready,

  output                         data_out_valid,
  output [OUTPUT_DATA_WIDTH-1:0] data_out [NUM_DATA_OUTPUTS-1:0],
  input                          data_out_ready

);

// CYCLES_TO_WAIT_AFTER_OUTPUT:
//  -parameter width
localparam integer CYCLES_TO_WAIT_AFTER_OUTPUT_WIDTH = $clog2(CYCLES_TO_WAIT_AFTER_OUTPUT+1);
//  -start value for counter when counting down
localparam integer OUTPUT_WAIT_COUNTER_START_VALUE = CYCLES_TO_WAIT_AFTER_OUTPUT > 0
                                                   ? CYCLES_TO_WAIT_AFTER_OUTPUT - 1
                                                   : 0;

// count down our wait time after output
reg [CYCLES_TO_WAIT_AFTER_OUTPUT_WIDTH-1:0] output_wait_counter = OUTPUT_WAIT_COUNTER_START_VALUE;

// input buffer signals
wire                        buffered_data_in_valid;
wire [INPUT_DATA_WIDTH-1:0] buffered_data_in [NUM_DATA_INPUTS-1:0];
wire                        buffered_data_in_ready;


genvar output_num;


//#####################################
// layer
//#####################################

// control signals
wire layer_ap_clk;
wire layer_ap_rst;
wire layer_ap_start;
wire layer_ap_done;
wire layer_ap_idle;
wire layer_ap_ready;
wire layer_ap_ce;

// data input/output for layer
wire [INPUT_DATA_WIDTH-1:0]  layer_data_in  [NUM_DATA_INPUTS-1:0];
wire [OUTPUT_DATA_WIDTH-1:0] layer_data_out [NUM_DATA_OUTPUTS-1:0];

// track when the layer is ready to accept new input data
wire layer_accepting_input;



//#####################################
// output buffer
//#####################################


// buffer states
typedef enum {BUFFER_IDLE, BUFFER_FULL} buffer_state_t;

// output buffer state machine
buffer_state_t output_buffer_state;


// store data from act fn if global output isn't ready
reg  [OUTPUT_DATA_WIDTH-1:0] output_buffer [NUM_DATA_OUTPUTS-1:0];

// high when we are buffering data
wire output_buffer_full;



//#####################################
// waiting state machine
//#####################################

// states
typedef enum {NOT_WAITING, WAITING} waiting_state_t;

// waiting state
waiting_state_t waiting_state;

// boolean tracking if we are currently in the waiting state
wire waiting;


//#####################################
// force latency state machine
//#####################################

// latency countdown states
//typedef enum {IDLE, PROCESSING} latency_count_state_t;

// latency countdown state machine
//latency_count_state_t latency_count_state;


//#############################################################################
// input buffer
//#############################################################################

intermediate_buffer #(
  .NUM_DATA_INPUTS     (NUM_DATA_INPUTS),
  .NUM_BUFFERS         (NUM_INPUT_BUFFERS),
  .MAINTAIN_TIME_ORDER ("false"),
  .DATA_WIDTH          (INPUT_DATA_WIDTH)

)
inst_input_buffer(
  .clk (clk),

  .data_in_valid  (data_in_valid),
  .data_in        (data_in),
  .data_in_ready  (data_in_ready),

  .data_out_valid (buffered_data_in_valid),
  .data_out       (buffered_data_in),
  .data_out_ready (buffered_data_in_ready)
);


//#############################################################################
// register some signals
//#############################################################################

// global
reg data_out_valid_prev = 1'b0;
reg data_out_ready_prev = 1'b0;

// layer
reg layer_ap_idle_prev          = 1'b0;
reg layer_ap_done_prev          = 1'b0;

// remember the previous state of signals
always @(posedge clk) begin
  data_out_valid_prev <= data_out_valid;
  data_out_ready_prev <= data_out_ready;
  layer_ap_idle_prev  <= layer_ap_idle;
  layer_ap_done_prev  <= layer_ap_done;
end

//#############################################################################



//#############################################################################
// DATA INPUT
//#############################################################################

assign layer_data_in = buffered_data_in;

// we signal (0-cycle) that we are ready for new data when:
//  -layer is accepting new input data (held constant this cycle)
//  AND
//  -there is no data needing to be held in the intermediate buffer (held constant this cycle)
/////////  AND
/////////  -if there is data to output now, that it is able to be output
//  AND
//  -we don't need to wait
//assign buffered_data_in_ready = layer_accepting_input & ~output_buffer_full & ~waiting;
//assign buffered_data_in_ready = layer_accepting_input
//                              & (~output_buffer_full | data_out_ready)
//                              & ~waiting;

// delay processing (i.e., layer is not ready for new input) when:
//  -output buffer is full and data cannot be output yet
//  OR
//  -layer should output this cycle, but output isn't ready
//  OR
//  -we need to wait
wire delay_processing = (output_buffer_full & ~data_out_ready)
                      | (wrapper_should_output & ~data_out_ready)
                      | waiting;

// we signal (0-cycle) that we are ready for new data when:
//  -layer is accepting new input data (held constant this cycle)
//  AND
//  -nothing to delay the processing of the data
assign buffered_data_in_ready = layer_accepting_input & ~delay_processing;


//#############################################################################



//#############################################################################
// LAYER AP SIGNALS
//#############################################################################

// clock and reset
assign layer_ap_clk = clk;
assign layer_ap_rst = rst;

// start processing new data when:
//  -we get the global signal to start
//  AND
//  -layer is accepting new data
//  AND
//  -the output buffer is clear to accept new data
//assign layer_ap_start = buffered_data_in_valid & layer_accepting_input & ~output_buffer_full & ~waiting;
assign layer_ap_start = buffered_data_in_valid & layer_accepting_input & (~output_buffer_full | data_out_ready)  & ~waiting;
//assign layer_ap_start = buffered_data_in_valid & layer_accepting_input & ~delay_processing;

assign layer_ap_ce = 1'b1; //ap_ce;


//#############################################################################
// LAYER ACCEPTING INPUT
//#############################################################################

generate

  // if no forced initiation interval:
  //  -deal with the ap_* signals (0-cycled and awkward...)
  if (FORCE_II_CYLES <= 0) begin

    // signal that JUST THE LAYER can accept input (IGNORING THE BUFFER):
    //  -we were idle last cycle (layer output wire is 0-cycle toggled)
    //  OR
    //  -we were done last cycle (layer output wire is 0-cycle toggled) AND the data was accepted by the output
    assign layer_accepting_input = layer_ap_idle_prev | (layer_ap_done_prev & data_out_ready_prev); // | (data_out_valid & data_out_ready);
    //assign layer_accepting_input = 1'b1;

  end


  // initiation interval of one
  else if (FORCE_II_CYLES == 1) begin
    assign layer_accepting_input = 1'b1;

  end


  // initiation interval larger than one
  else begin

    reg [FORCE_II_CYLES-1:0] layer_accepting_input_r = 0;


    //###########################################
    // II countdown state machine: setup
    //###########################################

    // countdown states
    typedef enum {IDLE, WAITING} ii_count_state_t;

    // countdown state machine
    ii_count_state_t ii_count_state;

    // FORCE_II_CYLES:
    //  -parameter width
    localparam integer FORCE_II_CYLES_WIDTH = $clog2(FORCE_II_CYLES+1);

    // count down our latency
    reg [FORCE_II_CYLES_WIDTH-1:0] ii_countdown = FORCE_II_CYLES-1;



    //###########################################
    // II countdown state machine: operations
    //###########################################

    always @(posedge clk) begin
      case (ii_count_state)

        // when new data comes in
        //  -transition to the waiting state
        //  -start the countdown
        IDLE: begin

          layer_accepting_input_r <= 1'b0;

          if (data_in_valid === 1'b1 & ~delay_processing) begin
            ii_countdown   <= ii_countdown - 1;
            ii_count_state <= WAITING;
          end

        end

        WAITING: begin

          // if this is the last cycle to wait
          //  -reset the countdown
          //  -transition back to idle
          if (ii_countdown == 0) begin
            ii_countdown            <= FORCE_II_CYLES-1;
            ii_count_state          <= IDLE;
            layer_accepting_input_r <= 1'b1;
          end

          // else, keep counting down
          else begin
            ii_countdown <= ii_countdown - 1;
          end

        end
      endcase
    end

    assign layer_accepting_input = layer_accepting_input_r;

  end
endgenerate


//#############################################################################


//#############################################################################
// OUTPUT BUFFER
//#############################################################################

// buffer is full when we are in the full state
assign output_buffer_full = output_buffer_state == BUFFER_FULL;


always @(posedge clk) begin
  case (output_buffer_state)

    // not storing anything, monitoring the output from the layer
    BUFFER_IDLE: begin

      // if we need to hold the output data from layer
      //if (layer_ap_done & ~layer_ap_idle & ~data_out_ready) begin
      if (wrapper_should_output & ~data_out_ready) begin
        output_buffer_state <= BUFFER_FULL;
        output_buffer       <= layer_data_out;
      end
    end

    // holding data from the layer, waiting for output to use it
    BUFFER_FULL: begin

      // if output is ready to accept our held data
      if (data_out_ready) begin
        output_buffer_state <= BUFFER_IDLE;
      end
    end

    default:
      output_buffer_state <= BUFFER_IDLE;
  endcase
end

//#############################################################################



//#############################################################################
// WAITING
//#############################################################################

// we are waiting when we are in the waiting state
assign waiting = waiting_state == WAITING;


always @(posedge clk) begin
  case (waiting_state)

    // no need to wait
    NOT_WAITING: begin

      // if there is an output and we need to wait
      //if (layer_ap_done & ~layer_ap_idle & output_wait_counter != 0) begin
      if (wrapper_should_output & output_wait_counter != 0) begin
        waiting_state       <= WAITING;
        output_wait_counter <= output_wait_counter - 1;
      end
    end

    // wait
    WAITING: begin

      // if we are done waiting
      if (output_wait_counter == 0) begin
        waiting_state       <= NOT_WAITING;
        output_wait_counter <= OUTPUT_WAIT_COUNTER_START_VALUE;
      end

      // still more waiting to do
      else begin
        output_wait_counter <= output_wait_counter - 1;
      end
    end

    default:
      waiting_state <= NOT_WAITING;
  endcase
end

//#############################################################################


//#############################################################################
// OUTPUT DATA
//#############################################################################

// data output comes from:
//  -the output buffer, when we're buffering
//  -else, directly passed through from the layer output
generate
for (output_num = 0; output_num < NUM_DATA_OUTPUTS; output_num = output_num + 1) begin
  assign data_out[output_num] = output_buffer_full
                              ? output_buffer[output_num]
                              : layer_data_out[output_num];
end
endgenerate

// output is valid when:
//  -the layer has processessed data AND is outputting it now
//  OR
//  -there is data in the output buffer
//assign data_out_valid = (~layer_ap_idle & layer_ap_done) | output_buffer_full;
assign data_out_valid = wrapper_should_output | output_buffer_full;

//assign data_out_valid = data_out_ready & ( (~dense_ap_idle & dense_ap_done) | intermediate_buffer_full );
//assign data_out_valid = (act_fn_ap_done & ~act_fn_ap_idle) | output_buffer_full;

//#############################################################################





//#############################################################################
// WRAPPER SHOULD OUTPUT
//#############################################################################

wire wrapper_should_output;

generate

// no forced latency
if (FORCE_LATENCY_CYCLES <= 0) begin
  assign wrapper_should_output = ~layer_ap_idle & layer_ap_done;

end

// simple case of latency being 1 cycle
else if (FORCE_LATENCY_CYCLES == 1) begin

  reg wrapper_should_output_r = 1'b0;

  // output next cycle if input this cycle
  always @(posedge clk) begin
    wrapper_should_output_r <= layer_ap_start;
  end

  assign wrapper_should_output = wrapper_should_output_r;

end

else begin

  reg [FORCE_LATENCY_CYCLES-1:0] wrapper_should_output_r = 0;

  // output next cycle if input this cycle
  always @(posedge clk) begin
    wrapper_should_output_r <= {layer_ap_start, wrapper_should_output_r[FORCE_LATENCY_CYCLES-1:1]};
  end

  assign wrapper_should_output = wrapper_should_output_r[0];

end
endgenerate



/*
// is the wrapper output valid
wire wrapper_should_output;
reg  wrapper_should_output_r = 1'b0;

generate

// no forced latency
if (FORCE_LATENCY_CYCLES <= 0) begin
  assign wrapper_should_output = ~layer_ap_idle & layer_ap_done;

end

// simple case of latency being 1 cycle
else if (FORCE_LATENCY_CYCLES == 1) begin

  assign wrapper_should_output = wrapper_should_output_r;

  // output next cycle if input this cycle
  always @(posedge clk) begin
    wrapper_should_output_r <= layer_ap_start;
  end

end


// forced latency of more than 1 cycle
else begin

  // FORCE_LATENCY_CYCLES:
  //  -parameter width
  localparam integer FORCE_LATENCY_CYCLES_WIDTH = $clog2(FORCE_LATENCY_CYCLES+1);

  // count down our latency
  reg [FORCE_LATENCY_CYCLES_WIDTH-1:0] latency_countdown = FORCE_LATENCY_CYCLES-1;


  assign wrapper_should_output = wrapper_should_output_r;

  always @(posedge clk) begin
    case (latency_count_state)

      // wait for data to come in
      IDLE: begin

        wrapper_should_output_r <= 1'b0;

        if (layer_ap_start) begin
          latency_countdown   <= latency_countdown - 1;
          latency_count_state <= PROCESSING;
        end

      end

      // layer is processing the data
      PROCESSING: begin

        // if this is the last cycle to wait
        //  -reset the countdown
        //  -transition back to idle
        if (latency_countdown == 0) begin
          latency_countdown       <= FORCE_LATENCY_CYCLES-1;
          wrapper_should_output_r <= 1'b1;
          latency_count_state     <= IDLE;
        end

        // else, keep counting down
        else begin
          latency_countdown <= latency_countdown - 1;
        end

      end
    endcase
  end
end
endgenerate
*/

//#############################################################################


//#############################################################################
// PASTE HERE
//#############################################################################

//DOLLARSIGN--sourceInstantiation
myproject_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s grp_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s_fu_45(

    // control signals
    .ap_clk   (layer_ap_clk),
    .ap_rst   (layer_ap_rst),
    .ap_start (layer_ap_start),
    .ap_done  (layer_ap_done),
    .ap_idle  (layer_ap_idle),
    .ap_ready (layer_ap_ready),
    .dense_2_input_ce0 (layer_dense_2_input_ce0),
    .dense_2_input_ce1 (layer_dense_2_input_ce1),

    // data signals
    .data_0_V_read(layer_data_in[0]),
    .data_1_V_read(layer_data_in[1]),

    // return signals
    .ap_return_0(layer_data_out[0]),
    .ap_return_1(layer_data_out[1]),
    .ap_return_2(layer_data_out[2]),
    .ap_return_3(layer_data_out[3]),
    .ap_return_4(layer_data_out[4]),
    .ap_return_5(layer_data_out[5]),
    .ap_return_6(layer_data_out[6]),
    .ap_return_7(layer_data_out[7]),
    .ap_return_8(layer_data_out[8]),
    .ap_return_9(layer_data_out[9])
);



/*
// signal declarations
localparam NUM_DENSE_DATA_OUTPUTS  = 16;
localparam DENSE_DATA_OUTPUT_WIDTH = 16;


// hard-coded output signals
assign act_fn_ap_done = dense_ap_done;
assign act_fn_ap_idle = dense_ap_idle;



dense_latency_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_2 grp_dense_latency_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_2_fu_127(

    // control signals
    .ap_clk   (dense_ap_clk),
    .ap_rst   (dense_ap_rst),
    .ap_start (dense_ap_start),
    .ap_done  (dense_ap_done),
    .ap_idle  (dense_ap_idle),
    .ap_ready (dense_ap_ready),
    .ap_ce    (dense_ap_ce),

    // data signals
    .data_V_read(buffered_data_in[0]),

    // return signals
    .ap_return_0(dense_data_out[0]),
    .ap_return_1(dense_data_out[1]),
    .ap_return_2(dense_data_out[2]),
    .ap_return_3(dense_data_out[3]),
    .ap_return_4(dense_data_out[4]),
    .ap_return_5(dense_data_out[5]),
    .ap_return_6(dense_data_out[6]),
    .ap_return_7(dense_data_out[7]),
    .ap_return_8(dense_data_out[8]),
    .ap_return_9(dense_data_out[9]),
    .ap_return_10(dense_data_out[10]),
    .ap_return_11(dense_data_out[11]),
    .ap_return_12(dense_data_out[12]),
    .ap_return_13(dense_data_out[13]),
    .ap_return_14(dense_data_out[14]),
    .ap_return_15(dense_data_out[15])
);
*/

//#############################################################################

//DOLLARSIGN--wrapperName
endmodule: wrapper_myproject_dense_latency_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_config2_s
