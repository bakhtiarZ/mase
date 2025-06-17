/*
Processing element:
-control:  ap_ctrl_hs
-latency:  deterministic
*/

`default_nettype wire
`timescale 1ps / 1ps

//DOLARSIGN-name
module wrapper_tanh_ap_fixed_ap_fixed_16_6_5_3_0 #(

  // config-specific info, if any
  CONFIGURATION_INFO = "",

  // general parameters
  INPUT_DATA_WIDTH  = 0, // ADDRESS_WIDTH
  OUTPUT_DATA_WIDTH = 0, // DATA_WIDTH

  // number of independent data-paths this element can serve
  NUM_INTERFACES = 1,

  // what the compute pool THINKS this element's latency is
  //  -useful if we want to double-check
  ELEMENT_LATENCY = 1,

  // number of intermediate registers to use before passing data to element
  NUM_PROCESSING_REGISTERS = 0

)(
  input clk,
  input rst,

  // ASK
  input                          ask_addr_valid [NUM_INTERFACES-1: 0],
  input  [INPUT_DATA_WIDTH-1:0]  ask_addr       [NUM_INTERFACES-1: 0],
  output                         ask_processing [NUM_INTERFACES-1: 0],

  output                         ask_data_valid [NUM_INTERFACES-1: 0],
  output [OUTPUT_DATA_WIDTH-1:0] ask_data       [NUM_INTERFACES-1: 0],

  // ANSWER
  input                          ans_addr_valid [NUM_INTERFACES-1: 0],
  input  [INPUT_DATA_WIDTH-1:0]  ans_addr       [NUM_INTERFACES-1: 0],
  output                         ans_processing [NUM_INTERFACES-1: 0],

  output                         ans_data_valid [NUM_INTERFACES-1: 0],
  output [OUTPUT_DATA_WIDTH-1:0] ans_data       [NUM_INTERFACES-1: 0]

);

//#############################################################################
// PASTE HERE
//#############################################################################

//DOLARSIGN-knownLatency
// the latency we know this PE to be
//  -used to (optionally) confirm that the compute pool has the correct information about us
localparam KNOWN_LATENCY = 1; //1;

//#############################################################################

// CHECK: compute pool information on latency matches ours
if (ELEMENT_LATENCY != KNOWN_LATENCY) begin
  $error("ERROR: element latency should be %d", KNOWN_LATENCY);
  $fatal("ERROR: element latency should be %d", KNOWN_LATENCY);
end

// CHECK: no intermediate register support
if (NUM_PROCESSING_REGISTERS != 0) begin
  $error("ERROR: NUM_PROCESSING_REGISTERS != 0 is not supported");
  $fatal("ERROR: NUM_PROCESSING_REGISTERS != 0 is not supported");
end


genvar interface_num;


//#############################################################################
// ASK
//#############################################################################

generate
for (interface_num = 0; interface_num < NUM_INTERFACES; interface_num = interface_num + 1) begin

  assign ask_processing[interface_num] = 1'b0;
  assign ask_data_valid[interface_num] = 0;
  assign ask_data[interface_num]       = 0;

end
endgenerate

//#############################################################################


//#############################################################################
// ANSWER
//#############################################################################

tri0 ap_start;
wire ap_ready;

//assign ap_ready = 1'b0;

wire ap_clk, ap_rst, ap_done, ap_idle;

assign ap_clk = clk;
assign ap_rst = rst;

//#############################################################################
// PASTE HERE, NOV-2022 EDITION
//#############################################################################



// NOTE:
// -For modules with >1 interface:
//   -ap_* signals are for the WHOLE module, and not set at an individual interface level
//   -need to set ap_start when any interface is valid, then propagate this for the output valid signal
//   -we can't rely on ap_done to signal valid as we don't know which interface(s) it is signalling
//DOLARSIGN-instantiation
tanh_ap_fixed_ap_fixed_16_6_5_3_0 inst_pe(
  .ap_clk (ap_clk),
  .ap_rst (ap_rst),
  .ap_start (ap_start),
  .ap_done (ap_done),
  .ap_idle (ap_idle),
  .ap_ready (ap_ready),
  .ap_ce (1'b1),

  // data input
  .data_0_V_read (ans_addr[0]),
  .data_1_V_read (ans_addr[1]),

  // data output
  .ap_return_0 (ans_data[0]),
  .ap_return_1 (ans_data[1])
);

/*
//tanh_ap_fixed_ap_fixed_16_6_5_3_0_tanh_config10_s inst_pe(
single_PE_tanh_ap_fixed_ap_fixed_16_6_5_3_0 inst_pe(
  .ap_clk   (ap_clk),
  .ap_rst   (ap_rst),
  .ap_start (ap_start),
  .ap_done  (ap_done),
  .ap_idle  (ap_idle),
  .ap_ready (ap_ready),
  .ap_ce    (1'b1),

  // data input
  .data_0_V_read (ans_addr[0]),
  .data_1_V_read (ans_addr[1]),

  // data output
  .ap_return_0   (ans_data[0]),
  .ap_return_1   (ans_data[1])
);
*/

//#############################################################################


// general (non-paste), but "read" mode specific
//  -NOTE:
//    -THIS IS FOR THE PROCESSING ELEMENT, NOT THE POOL
//    -this will be fine for elements with known latency
//    -will need to be changed for elements with variable latency
//      -process:
//        -need FIFO of valid signals
//        -just propagating won't work as easily as it gets too complex to track

genvar g_propagate;

// propagate input valid signal to use as output valid
//  -propagate it <latency> cycles
localparam integer NUM_VALID_PROPAGATE_STAGES = ELEMENT_LATENCY;

reg [NUM_VALID_PROPAGATE_STAGES-1:0] valid_propagate [NUM_INTERFACES-1:0];
initial begin
  int k;
  for (k = 0; k < NUM_INTERFACES; k = k + 1) begin
    valid_propagate[k] <= 0;
  end
end

generate
for (interface_num = 0; interface_num < NUM_INTERFACES; interface_num = interface_num + 1) begin

  // signal the module to start if ANY interface is valid
  assign ap_start = ans_addr_valid[interface_num] ? 1'b1 : 1'bz;

  // can process data if the module is ready
  //assign ans_processing[interface_num] = ap_ready; // & ans_addr_valid[interface_num]; // & ap_start;
  //assign ans_processing[interface_num] = 1'b1;
  assign ans_processing[interface_num] = ap_ready | ap_done | ap_idle;


  //always @(posedge clk) begin
  //
  //  // remember ap_ready
  //  ap_ready_prev <= ap_ready;
  //
  //  // can process answer if:
  //  //  -
  //
  //  // can't process answer input if
  //  //  -last cycle had a valid and ready signal
  //  if (ap_ready_prev & ans_addr_valid_prev[interface_num])
  //  ans_processing_next[interface_num] <= ~(ans_addr_valid[interface_num] & ap_ready);
  //end


  // propagate the input data valid signal to use as output valid
  for (g_propagate = 0; g_propagate < NUM_VALID_PROPAGATE_STAGES; g_propagate = g_propagate + 1) begin
    always @(posedge clk) begin
      if (g_propagate == 0)
        valid_propagate[interface_num][g_propagate] <= ans_addr_valid[interface_num];
      else
        valid_propagate[interface_num][g_propagate] <= valid_propagate[interface_num][g_propagate-1];
    end
  end

  assign ans_data_valid[interface_num] = valid_propagate[interface_num][NUM_VALID_PROPAGATE_STAGES-1];

end
endgenerate

//#############################################################################

//DOLARSIGN-name
endmodule: wrapper_tanh_ap_fixed_ap_fixed_16_6_5_3_0
