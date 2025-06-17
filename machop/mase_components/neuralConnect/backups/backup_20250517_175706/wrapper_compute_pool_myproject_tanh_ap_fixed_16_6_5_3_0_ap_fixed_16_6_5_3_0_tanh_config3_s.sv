
`default_nettype wire
`timescale 1ns / 1ps

//DOLLARSIGN--NAME
module wrapper_compute_pool_myproject_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s #(

  // configuration information for PEs (if any)
  CONFIGURATION_INFO = "",

  // data path and function info
  NUM_DATA_PATHS     = 0, // number of parallel data paths presented at the input
  FN_ARGUMENT_WIDTH  = 0, // total width of the incoming function call
  DATA_WIDTH         = 0, // width of function call result



  FEED_FORWARD_START = -1,
  FEED_FORWARD_END   = -1,

  // compute element info
  NUM_COMPUTE_UNITS         = 0, //<<NUM_COMPUTE_UNITS>>,                 // total number of compute elements
  SUB_MEMORY_ADDRESS_WIDTH  = 0, //<<SUB_MEMORY_ADDRESS_BIT_WIDTH>>, // address bits used to read from sub-memory (in case is less than FN_ARGUMENT_WIDTH, e.g., 12-bit address for 16-bit data)

  integer ELEMENT_LATENCIES                 [NUM_COMPUTE_UNITS/2-1:0] = {0}, // latency of each element in the pool

  integer SUB_MEM_TO_INSTRUCTION_ASSIGNMENT [NUM_COMPUTE_UNITS-1:0] = {0}, // positions for compute units to be assigned in the pool,
  integer SUB_MEM_TYPE                      [NUM_COMPUTE_UNITS-1:0] = {0}  // type of each compute unit

)(
  input                                         clk,
  input                                         rst,

  input  [NUM_DATA_PATHS-1:0]                   data_in_valid,
  output [NUM_DATA_PATHS-1:0]                   data_in_ready,
  input  [NUM_DATA_PATHS*FN_ARGUMENT_WIDTH-1:0] data_in,

  output [NUM_DATA_PATHS-1:0]                   data_out_valid,
  input  [NUM_DATA_PATHS-1:0]                   data_out_ready,
  output [NUM_DATA_PATHS*(DATA_WIDTH+FEED_FORWARD_START-FEED_FORWARD_END)-1:0]        data_out

);


//#############################################################################
// general setup

localparam ASK = 0;
localparam ANS = 1;

// HARD-CODED FOR NOW
localparam integer NUM_SUB_MEMORY_PORTS =  1;


// each memory has one interface for ASK and one for ANS
localparam integer NUM_ASK_INTERFACES = 1;
localparam integer NUM_ANS_INTERFACES = 1;
localparam integer TOTAL_NUM_ASK_ANS_INTERFACES = NUM_ASK_INTERFACES + NUM_ANS_INTERFACES;


genvar sub_mem, sub_mem_port, instruction_num;

//#############################################################################
// carousel setup

// widths of the carousels
//  -in matches data_in, out matches data_out
localparam integer CAROUSEL_IN_WIDTH   = NUM_DATA_PATHS*FN_ARGUMENT_WIDTH;
localparam integer CAROUSEL_OUT_WIDTH  = NUM_DATA_PATHS*DATA_WIDTH;

// control
reg                      stop_carousel;
reg [NUM_DATA_PATHS-1:0] data_in_valid_store;

// pool state
typedef enum {IDLE, PROCESSING, WAITING_TO_OUTPUT} pool_state_t;
pool_state_t pool_state;

// carousel in
wire [NUM_DATA_PATHS-1:0]    data_in_carousel_valid;//      = {NUM_DATA_PATHS{1'b0}};
reg  [NUM_DATA_PATHS-1:0]    data_in_carousel_valid_prev = {NUM_DATA_PATHS{1'b0}};
wire [CAROUSEL_IN_WIDTH-1:0] data_in_carousel;//            = {CAROUSEL_IN_WIDTH{1'b0}};
reg  [CAROUSEL_IN_WIDTH-1:0] data_in_carousel_prev       = {CAROUSEL_IN_WIDTH{1'b0}};

// carousel out
wire [NUM_DATA_PATHS-1:0]     data_out_carousel_valid;//      = {NUM_DATA_PATHS{1'b1}};
reg  [NUM_DATA_PATHS-1:0]     data_out_carousel_valid_prev = {NUM_DATA_PATHS{1'b1}};
wire [CAROUSEL_OUT_WIDTH-1:0] data_out_carousel;//            = {CAROUSEL_OUT_WIDTH{1'b0}};
reg  [CAROUSEL_OUT_WIDTH-1:0] data_out_carousel_prev       = {CAROUSEL_OUT_WIDTH{1'b0}};


//#############################################################################
// sub-memory setup

// input to block rams
wire                                sub_mem_addr_valid [NUM_COMPUTE_UNITS-1:0][NUM_SUB_MEMORY_PORTS-1:0];
wire [SUB_MEMORY_ADDRESS_WIDTH-1:0] sub_mem_addr       [NUM_COMPUTE_UNITS-1:0][NUM_SUB_MEMORY_PORTS-1:0];
wire                                sub_mem_processing [NUM_COMPUTE_UNITS-1:0][NUM_SUB_MEMORY_PORTS-1:0];

// output from block rams
wire                                sub_mem_data_valid [NUM_COMPUTE_UNITS-1:0][NUM_SUB_MEMORY_PORTS-1:0];
wire [DATA_WIDTH-1:0]               sub_mem_data       [NUM_COMPUTE_UNITS-1:0][NUM_SUB_MEMORY_PORTS-1:0];



//#############################################################################
// module input and ouput

//reg  data_in_ready_r;

reg [NUM_DATA_PATHS-1:0] data_out_valid_prev = {NUM_DATA_PATHS{1'b0}};
reg [NUM_DATA_PATHS-1:0] data_out_ready_prev = {NUM_DATA_PATHS{1'b0}};


reg [NUM_DATA_PATHS-1:0] data_in_valid_prev = {NUM_DATA_PATHS{1'b0}};
reg [NUM_DATA_PATHS-1:0] data_in_ready_prev = {NUM_DATA_PATHS{1'b1}};
//reg [NUM_DATA_PATHS-1:0] data_in_ready_prev = {NUM_DATA_PATHS{1'b0}};

wire data_out_valid_agg;


//#############################################################################
// sub-memory group setup
//
//  -a group is made up of the sub-mems which all look at the same instruction
//  -e.g., 32 sub-mems, each with 2 ports (= 64 ports) will wrap around the carousel
//   if there are fewer than 64 instructions:
//     -32 instruction = instruction 0 will be interrogated by sub-mem[0][0] and sub-mem[16][0]
//     -16 instruction = instruction 0 will be interrogated by sub-mem[0][0], sub-mem[8][0], sub-mem[16][0] and sub-mem[24][0]


//localparam integer SUB_MEMS_PER_GROUP = $ceil((NUM_COMPUTE_UNITS * NUM_SUB_MEMORY_PORTS) / NUM_DATA_PATHS);

// how many sub-memory groups are there
//  -if we have more ports than instructions, then multiple sub-memories check an instruction each cycle, so we have <NUM_DATA_PATHS> groups
//  -if we have more instructions than ports, then we are limited by the number of sub-memories, so we have <NUM_PORTS> groups
localparam integer NUM_PORTS  = NUM_COMPUTE_UNITS * NUM_SUB_MEMORY_PORTS;
localparam integer NUM_GROUPS = NUM_DATA_PATHS;
//localparam integer NUM_GROUPS = NUM_PORTS >= NUM_DATA_PATHS
//                              ? NUM_DATA_PATHS
//                              : NUM_PORTS;

// wires that are pulled low on Z
tri0                  group_input_processing [NUM_GROUPS-1:0];
tri0                  group_data_valid       [NUM_GROUPS-1:0];
tri0 [DATA_WIDTH-1:0] group_data             [NUM_GROUPS-1:0];


//#############################################################################
// state machine

//localparam NUM_STATES       = 4;
//localparam NUM_STATES_WIDTH = $clog2(NUM_STATES);
//localparam [NUM_STATES_WIDTH-1:0]
//  STATE_IDLE                     = 0,
//  STATE_PROCESSING               = 1,
//  STATE_WAIT_FOR_PROCESS_LATENCY = 2,
//  STATE_OUTPUT                   = 3;
//reg [NUM_STATES_WIDTH-1:0] state = STATE_IDLE;



// the maximum number of cycles required to process all the input instructions
localparam integer TOTAL_CYCLES       = $ceil(NUM_DATA_PATHS/NUM_SUB_MEMORY_PORTS);
//localparam integer TOTAL_CYCLES_WIDTH = $clog2(TOTAL_CYCLES);


// counts the cycle we are on when processing the input instructions
//reg [TOTAL_CYCLES_WIDTH-1:0]    cycle_count;


initial begin
  int k;
  for (k = 0; k < NUM_COMPUTE_UNITS; k = k + 1) begin
    $display("Mapping sub mem to group: %d: %d", k, map_sub_mem_to_group(k,0));
  end
  for (k = 0; k < NUM_DATA_PATHS; k = k + 1) begin
    $display("Mapping instruction to group: %d: %d", k, map_instruction_to_group(k));
  end
end



//#############################################################################
// instantiate the sub-memories

// assign the clock to each port
wire sub_mem_clk [NUM_SUB_MEMORY_PORTS-1:0];
generate
for (sub_mem_port = 0; sub_mem_port < NUM_SUB_MEMORY_PORTS; sub_mem_port = sub_mem_port + 1) begin
  assign sub_mem_clk[sub_mem_port] = clk;
end
endgenerate



//#############################################################################
// TRACK THE POOL STATE SO WHEN WE KNOW WHEN TO ROTATE THE CAROUSEL
//#############################################################################

// should only rotate when processing
assign stop_carousel = ~(pool_state == PROCESSING);


always @(posedge clk) begin
  case (pool_state)

    // not processing anything, monitoring the input data
    IDLE: begin

      // if we should start processing
      if (data_in_valid > 0 & data_in_ready > 0) begin
        pool_state          <= PROCESSING;
        data_in_valid_store <= data_in_valid;
      end

      else begin
        data_in_valid_store <= 0;
      end
    end


    //
    PROCESSING: begin

      // when data is valid for output
      if (data_out_valid == data_in_valid_store) begin

        // if the output receiver is ready
        if (data_out_ready == data_in_valid_store) begin

          // if we have new input data right now, stay in the processing state
          if (data_in_valid > 0 & data_in_ready > 0) begin
            pool_state          <= PROCESSING;
            data_in_valid_store <= data_in_valid;
          end

          // else, no new data, so go back to idle
          else begin
            pool_state <= IDLE;
          end
        end

        // else, output receiver isn't ready, so wait for the output
        else begin
          pool_state <= WAITING_TO_OUTPUT;
        end
      end
    end

    WAITING_TO_OUTPUT: begin

      // if output is ready to accept our data
      if (data_out_ready == data_in_valid_store) begin

        // if we have new input data right now, go to the processing state
        if (data_in_valid > 0 & data_in_ready > 0) begin
          pool_state          <= PROCESSING;
          data_in_valid_store <= data_in_valid;
        end

        // else, no new data, so go back to idle
        else begin
          pool_state <= IDLE;
        end
      end

    end

    default:
      pool_state <= IDLE;
  endcase
end

//#############################################################################


/*
//#############################################################################
// CAN USE BELOW IF ALL THE PROCESSING ELEMENTS ARE THE SAME TYPE (UNTESTED CODE)
//#############################################################################

genvar elem_num;

generate
for (elem_num = 0; elem_num < NUM_COMPUTE_UNITS; elem_num = elem_num + 2) begin: element

  proc_element #(

    // general parameters
    .ADDRESS_WIDTH (FN_ARGUMENT_WIDTH),
    .DATA_WIDTH    (DATA_WIDTH),
    .NUM_PORTS     (NUM_SUB_MEMORY_PORTS),

    // latency of this elemen
    .ELEMENT_LATENCY(ELEMENT_LATENCIES[0]),

    // number of intermediate registers to use before passing data to element
    .NUM_PROCESSING_REGISTERS (0)

  )
  inst_proc_element (
    .clk            (sub_mem_clk),

    // ask
    .ask_addr_valid (sub_mem_addr_valid[elem_num]),
    .ask_addr       (sub_mem_addr[elem_num]),
    .ask_processing (sub_mem_processing[elem_num]),

    .ask_data_valid (sub_mem_data_valid[elem_num]),
    .ask_data       (sub_mem_data[elem_num]),

    // ans g+<1>
    .ans_addr_valid (sub_mem_addr_valid[elem_num+1]),
    .ans_addr       (sub_mem_addr[elem_num+1]),
    .ans_processing (sub_mem_processing[elem_num+1]),

    .ans_data_valid (sub_mem_data_valid[elem_num+1]),
    .ans_data       (sub_mem_data[elem_num+1])
  );

end
endgenerate

//#############################################################################
//#############################################################################
*/


//#############################################################################
// PASTE HERE
//#############################################################################

//DOLLARSIGN-peInstantiations


  localparam integer NUM_INTERFACES_0 = 2;

  // ASK
  wire                          ask_addr_valid_0 [NUM_INTERFACES_0-1: 0];
  wire [FN_ARGUMENT_WIDTH-1:0]  ask_addr_0       [NUM_INTERFACES_0-1: 0];
  wire                          ask_processing_0 [NUM_INTERFACES_0-1: 0];

  wire                          ask_data_valid_0 [NUM_INTERFACES_0-1: 0];
  wire [DATA_WIDTH-1:0]         ask_data_0       [NUM_INTERFACES_0-1: 0];


  // ANSWER
  wire                          ans_addr_valid_0 [NUM_INTERFACES_0-1: 0];
  wire [FN_ARGUMENT_WIDTH-1:0]  ans_addr_0       [NUM_INTERFACES_0-1: 0];
  wire                          ans_processing_0 [NUM_INTERFACES_0-1: 0];

  wire                          ans_data_valid_0 [NUM_INTERFACES_0-1: 0];
  wire [DATA_WIDTH-1:0]         ans_data_0       [NUM_INTERFACES_0-1: 0];

// ASK assignments
assign ask_addr_valid_0 = {sub_mem_addr_valid[2], sub_mem_addr_valid[0]};
assign ask_addr_0       = {sub_mem_addr[2], sub_mem_addr[0]};
assign sub_mem_processing[0][0] = ask_processing_0[0];
assign sub_mem_processing[2][0] = ask_processing_0[1];

assign sub_mem_data_valid[0][0] = ask_data_valid_0[0];
assign sub_mem_data_valid[2][0] = ask_data_valid_0[1];

assign sub_mem_data[0][0] = ask_data_0[0];
assign sub_mem_data[2][0] = ask_data_0[1];

// ANS assignments
assign ans_addr_valid_0 = {sub_mem_addr_valid[3], sub_mem_addr_valid[1]};
assign ans_addr_0       = {sub_mem_addr[3], sub_mem_addr[1]};
assign sub_mem_processing[1][0] = ans_processing_0[0];
assign sub_mem_processing[3][0] = ans_processing_0[1];

assign sub_mem_data_valid[1][0] = ans_data_valid_0[0];
assign sub_mem_data_valid[3][0] = ans_data_valid_0[1];

assign sub_mem_data[1][0] = ans_data_0[0];
assign sub_mem_data[3][0] = ans_data_0[1];

wrapper_tanh_ap_fixed_ap_fixed_16_6_5_3_0 #(

  // config-specific info, if any
  .CONFIGURATION_INFO (),

  // general parameters
  .INPUT_DATA_WIDTH  (FN_ARGUMENT_WIDTH),
  .OUTPUT_DATA_WIDTH (DATA_WIDTH),

  // number of independent data-paths this element can serve
  .NUM_INTERFACES (NUM_INTERFACES_0),

  // what the compute pool THINKS this element's latency is
  //  -useful if we want to double-check
  .ELEMENT_LATENCY(ELEMENT_LATENCIES[0]),

  // number of intermediate registers to use before passing data to element
  .NUM_PROCESSING_REGISTERS (0)
)
element_0_tanh_ap_fixed_ap_fixed_16_6_5_3_0 (
  .clk            (clk),
  .rst            (rst),

  // ask
  .ask_addr_valid (ask_addr_valid_0),
  .ask_addr       (ask_addr_0),
  .ask_processing (ask_processing_0),

  .ask_data_valid (ask_data_valid_0),
  .ask_data       (ask_data_0),

  // ans g+<1>
  //  -NOTE: this position is NOT related to latency spacing
  .ans_addr_valid (ans_addr_valid_0),
  .ans_addr       (ans_addr_0),
  .ans_processing (ans_processing_0),

  .ans_data_valid (ans_data_valid_0),
  .ans_data       (ans_data_0)
);






/*
localparam integer NUM_INTERFACES_0 = 2;

// ASK
wire                          ask_addr_valid_0 [NUM_INTERFACES_0-1: 0];
wire [FN_ARGUMENT_WIDTH-1:0]  ask_addr_0       [NUM_INTERFACES_0-1: 0];
wire                          ask_processing_0 [NUM_INTERFACES_0-1: 0];

wire                          ask_data_valid_0 [NUM_INTERFACES_0-1: 0];
wire [DATA_WIDTH-1:0]         ask_data_0       [NUM_INTERFACES_0-1: 0];


// ANSWER
wire                          ans_addr_valid_0 [NUM_INTERFACES_0-1: 0];
wire [FN_ARGUMENT_WIDTH-1:0]  ans_addr_0       [NUM_INTERFACES_0-1: 0];
wire                          ans_processing_0 [NUM_INTERFACES_0-1: 0];

wire                          ans_data_valid_0 [NUM_INTERFACES_0-1: 0];
wire [DATA_WIDTH-1:0]         ans_data_0       [NUM_INTERFACES_0-1: 0];


// ASK
assign ask_addr_valid_0 = {sub_mem_addr_valid[2], sub_mem_addr_valid[0]};
assign ask_addr_0       = {sub_mem_addr[2], sub_mem_addr[0]};

assign sub_mem_processing[0][0] = ask_processing_0[0];
assign sub_mem_processing[2][0] = ask_processing_0[1];

assign sub_mem_data_valid[0][0] = ask_data_valid_0[0];
assign sub_mem_data_valid[2][0] = ask_data_valid_0[1];

assign sub_mem_data[0][0] = ask_data_0[0];
assign sub_mem_data[2][0] = ask_data_0[1];


// ANSWER
assign ans_addr_valid_0 = {sub_mem_addr_valid[3], sub_mem_addr_valid[1]};
assign ans_addr_0       = {sub_mem_addr[3], sub_mem_addr[1]};

assign sub_mem_processing[1][0] = ans_processing_0[0];
assign sub_mem_processing[3][0] = ans_processing_0[1];

assign sub_mem_data_valid[1][0] = ans_data_valid_0[0];
assign sub_mem_data_valid[3][0] = ans_data_valid_0[1];

assign sub_mem_data[1][0] = ans_data_0[0];
assign sub_mem_data[3][0] = ans_data_0[1];


pe_tanh_ap_fixed #(

  // configuration info, if any
  .CONFIGURATION_INFO (CONFIGURATION_INFO),

  // general parameters
  .ADDRESS_WIDTH  (FN_ARGUMENT_WIDTH),
  .DATA_WIDTH     (DATA_WIDTH),
  .NUM_INTERFACES (NUM_INTERFACES_0), //(NUM_SUB_MEMORY_PORTS),

  // latency of this element
  //  -this is what the pool thinks this latency is
  //  -element should check this at the high/meta level
  // GENERATION NOTE:
  //  -only the latency of the first element is passed
  .ELEMENT_LATENCY(ELEMENT_LATENCIES[0]),

  // number of intermediate registers to use before passing data to element
  .NUM_PROCESSING_REGISTERS (0)
)
element_0_pe_tanh_ap_fixed (
  .clk            (clk),
  .rst            (rst),

  // ask
  .ask_addr_valid (ask_addr_valid_0),
  .ask_addr       (ask_addr_0),
  .ask_processing (ask_processing_0),

  .ask_data_valid (ask_data_valid_0),
  .ask_data       (ask_data_0),

  // ans g+<1>
  //  -NOTE: this position is NOT related to latency spacing
  .ans_addr_valid (ans_addr_valid_0),
  .ans_addr       (ans_addr_0),
  .ans_processing (ans_processing_0),

  .ans_data_valid (ans_data_valid_0),
  .ans_data       (ans_data_0)
);
*/


/*
localparam integer NUM_INTERFACES = 2;

wire                      ask_addr_valid [NUM_INTERFACES-1: 0];

wire  [FN_ARGUMENT_WIDTH-1:0] ask_addr       [NUM_INTERFACES-1: 0];
wire                     ask_processing [NUM_INTERFACES-1: 0];

wire                     ask_data_valid [NUM_INTERFACES-1: 0];
wire [DATA_WIDTH-1:0]    ask_data       [NUM_INTERFACES-1: 0];

  // ANSWER
wire                      ans_addr_valid [NUM_INTERFACES-1: 0];
wire  [FN_ARGUMENT_WIDTH-1:0] ans_addr       [NUM_INTERFACES-1: 0];
wire                     ans_processing [NUM_INTERFACES-1: 0];

wire                     ans_data_valid [NUM_INTERFACES-1: 0];
wire [DATA_WIDTH-1:0]    ans_data       [NUM_INTERFACES-1: 0];


//assign ask_addr_valid = {sub_mem_addr_valid[0], sub_mem_addr_valid[2]};
//assign ask_addr       = {sub_mem_addr[0],       sub_mem_addr[2]};
assign ask_addr_valid = {sub_mem_addr_valid[SUB_MEM_TO_INSTRUCTION_ASSIGNMENT[0]], sub_mem_addr_valid[SUB_MEM_TO_INSTRUCTION_ASSIGNMENT[2]]};
assign ask_addr       = {sub_mem_addr[SUB_MEM_TO_INSTRUCTION_ASSIGNMENT[0]],       sub_mem_addr[SUB_MEM_TO_INSTRUCTION_ASSIGNMENT[2]]};

//assign sub_mem_processing[0][0] = ask_processing[0];
//assign sub_mem_processing[2][0] = ask_processing[1];
assign sub_mem_processing[SUB_MEM_TO_INSTRUCTION_ASSIGNMENT[0]][0] = ask_processing[0];
assign sub_mem_processing[SUB_MEM_TO_INSTRUCTION_ASSIGNMENT[2]][0] = ask_processing[1];

//assign sub_mem_data_valid[0][0] = ask_data_valid[0];
//assign sub_mem_data_valid[2][0] = ask_data_valid[1];
assign sub_mem_data_valid[SUB_MEM_TO_INSTRUCTION_ASSIGNMENT[0]][0] = ask_data_valid[0];
assign sub_mem_data_valid[SUB_MEM_TO_INSTRUCTION_ASSIGNMENT[2]][0] = ask_data_valid[1];

//assign sub_mem_data[0][0] = ask_data[0];
//assign sub_mem_data[2][0] = ask_data[1];
assign sub_mem_data[SUB_MEM_TO_INSTRUCTION_ASSIGNMENT[0]][0] = ask_data[0];
assign sub_mem_data[SUB_MEM_TO_INSTRUCTION_ASSIGNMENT[2]][0] = ask_data[1];

//assign ans_addr_valid = {sub_mem_addr_valid[1], sub_mem_addr_valid[3]};
//assign ans_addr       = {sub_mem_addr[1],       sub_mem_addr[3]};
assign ans_addr_valid = {sub_mem_addr_valid[SUB_MEM_TO_INSTRUCTION_ASSIGNMENT[1]], sub_mem_addr_valid[SUB_MEM_TO_INSTRUCTION_ASSIGNMENT[3]]};
assign ans_addr       = {sub_mem_addr[SUB_MEM_TO_INSTRUCTION_ASSIGNMENT[1]],       sub_mem_addr[SUB_MEM_TO_INSTRUCTION_ASSIGNMENT[3]]};

//assign sub_mem_processing[1][0] = ans_processing[0];
//assign sub_mem_processing[3][0] = ans_processing[1];
assign sub_mem_processing[SUB_MEM_TO_INSTRUCTION_ASSIGNMENT[1]][0] = ans_processing[0];
assign sub_mem_processing[SUB_MEM_TO_INSTRUCTION_ASSIGNMENT[3]][0] = ans_processing[1];

//assign sub_mem_data_valid[1][0] = ans_data_valid[0];
//assign sub_mem_data_valid[3][0] = ans_data_valid[1];
assign sub_mem_data_valid[SUB_MEM_TO_INSTRUCTION_ASSIGNMENT[1]][0] = ans_data_valid[0];
assign sub_mem_data_valid[SUB_MEM_TO_INSTRUCTION_ASSIGNMENT[3]][0] = ans_data_valid[1];

//assign sub_mem_data[1][0] = ans_data[0];
//assign sub_mem_data[3][0] = ans_data[1];
assign sub_mem_data[SUB_MEM_TO_INSTRUCTION_ASSIGNMENT[1]][0] = ans_data[0];
assign sub_mem_data[SUB_MEM_TO_INSTRUCTION_ASSIGNMENT[3]][0] = ans_data[1];



  pe_tanh_ap_fixed #(

    // configuration info, if any
    .CONFIGURATION_INFO (CONFIGURATION_INFO),

    // general parameters
    .ADDRESS_WIDTH  (FN_ARGUMENT_WIDTH),
    .DATA_WIDTH     (DATA_WIDTH),
    .NUM_INTERFACES (NUM_INTERFACES), //(NUM_SUB_MEMORY_PORTS),

    // latency of this element
    //  -this is what the pool thinks this latency is
    //  -element should check this at the high/meta level
    .ELEMENT_LATENCY(ELEMENT_LATENCIES[0]),

    // number of intermediate registers to use before passing data to element
    .NUM_PROCESSING_REGISTERS (0)

  )
  element_0_pe_tanh_ap_fixed (
    .clk            (clk),
    .rst            (rst),

    // ask
    .ask_addr_valid (ask_addr_valid),
    .ask_addr       (ask_addr),
    .ask_processing (ask_processing),

    .ask_data_valid (ask_data_valid),
    .ask_data       (ask_data),

    // ans g+<1>
    //  -NOTE: this position is NOT related to latency spacing
    .ans_addr_valid (ans_addr_valid),
    .ans_addr       (ans_addr),
    .ans_processing (ans_processing),

    .ans_data_valid (ans_data_valid),
    .ans_data       (ans_data)
  );
*/

//#############################################################################
//#############################################################################










// AUG-2022 CHANGES
/*
genvar g;
generate
for (g = 0; g < NUM_COMPUTE_UNITS; g = g + TOTAL_NUM_ASK_ANS_INTERFACES) begin

  //mem_ask_ans #(
  act_fn_tanh_32 #(

    // general parameters
    .ADDRESS_WIDTH (FN_ARGUMENT_WIDTH),
    .DATA_WIDTH    (DATA_WIDTH),
    .NUM_PORTS     (NUM_SUB_MEMORY_PORTS),

    // THIS IS HACKY AND SHOULD BE REPLACED BY THE PYTHON PRINTING
    .ELEMENT_LATENCY (ELEMENT_LATENCIES[g/TOTAL_NUM_ASK_ANS_INTERFACES]),

    // number of intermediate registers to use before passing data to element
    .NUM_PROCESSING_REGISTERS (0),

    // block ram memory specific paramters
    .BLOCK_RAM_BANK_NUMBER      (g),
    .BLOCK_RAM_ADDRESS_WIDTH (FN_ARGUMENT_WIDTH), //.BLOCK_RAM_ADDRESS_WIDTH (11),
    .BLOCK_RAM_DATA_WIDTH    (DATA_WIDTH) //.BLOCK_RAM_DATA_WIDTH    (8)
  )
  sub_mem (
    .clk            (sub_mem_clk),

    // ask
    .ask_addr_valid (sub_mem_addr_valid[g]),
    .ask_addr       (sub_mem_addr[g]),
    .ask_processing (sub_mem_processing[g]),

    .ask_data_valid (sub_mem_data_valid[g]),
    .ask_data       (sub_mem_data[g]),

    // ans g+<1>
    .ans_addr_valid (sub_mem_addr_valid[g+1]),
    .ans_addr       (sub_mem_addr[g+1]),
    .ans_processing (sub_mem_processing[g+1]),

    .ans_data_valid (sub_mem_data_valid[g+1]),
    .ans_data       (sub_mem_data[g+1])
  );

end
endgenerate
*/




//#############################################################################
// define the sub-memory groups

generate
for (sub_mem = 0; sub_mem < NUM_COMPUTE_UNITS; sub_mem = sub_mem + 1) begin
  for (sub_mem_port = 0; sub_mem_port < NUM_SUB_MEMORY_PORTS; sub_mem_port = sub_mem_port + 1) begin

    //localparam port = (sub_mem * NUM_SUB_MEMORY_PORTS) + sub_mem_port; localparam group_num = port % NUM_GROUPS;
    localparam group_num = map_sub_mem_to_group(sub_mem, sub_mem_port);

    // if this group read data from its instruction
    //  -i.e., the instruction is being processed, and is now invalid
    //DEBUG, DO NOT USE: assign group_input_processing[group_num] = 1'b1;
    assign group_input_processing[group_num] = sub_mem_processing[sub_mem][sub_mem_port] // sub_mem_addr_valid[sub_mem][sub_mem_port]
                                             ? 1'b1
                                             : 1'bz;

    // if this group is outputting data now
    assign group_data_valid[group_num] = sub_mem_data_valid[sub_mem][sub_mem_port] //sub_mem_data_valid[sub_mem][sub_mem_port][0]
                                       ? 1'b1
                                       : 1'bz;

    // the data being output by this group
    assign group_data[group_num] = sub_mem_data_valid[sub_mem][sub_mem_port] //sub_mem_data_valid[sub_mem][sub_mem_port][0]
                                 ? sub_mem_data[sub_mem][sub_mem_port]
                                 : {DATA_WIDTH{1'bz}};

  end
end
endgenerate



//#############################################################################
// rotate the data in carousel's valid signal

always @(posedge clk) begin

  // carousel in
  data_in_carousel_valid_prev  <= data_in_carousel_valid;
  data_in_carousel_prev        <= data_in_carousel;

  // carousel out
  data_out_carousel_valid_prev <= data_out_carousel_valid;
  data_out_carousel_prev       <= data_out_carousel;

  // global inputs
  data_in_valid_prev  <= data_in_valid;
  data_in_ready_prev  <= data_in_ready;

  // global outputs
  data_out_valid_prev <= data_out_valid;
  data_out_ready_prev <= data_out_ready;

end



/*
//#############################################################################
// state machine to start and stop the instruction processing

always @(posedge clk) begin
case (state)


  // waiting for input data
  STATE_IDLE: begin

    // nothing to do, nothing to output
    cycle_count <= 0;

    // if we have valid instructions and are ready to process them
    if (data_in_valid > 0 & data_in_ready) begin
      state <= STATE_PROCESSING;
      data_in_ready_r  <= 1'b0;

    end

    // else, keep waiting
    else
      data_in_ready_r  <= 1'b1;


  end


  // cycling the carousel and processing instructions
  STATE_PROCESSING: begin

    // update the cycle count MODULO <number of cycles for a full revolution of the carousel>
    //  -after <TOTAL_CYCLES> the carousel will have made a full revolution
    if (cycle_count == TOTAL_CYCLES-1)
      cycle_count <= 0;
    else
      cycle_count <= cycle_count + 1;

    // if the result has been read out, go back to idle and wait for a new input
    if (data_out_valid_agg & data_out_ready) begin
      state            <= STATE_IDLE;
      //data_out_valid_r <= 1'b0;
      data_in_ready_r  <= 1'b1;

    end


  end


endcase
end
*/




//#######################################################################
// carousel data
//
// -input:
//   -store new data when we get it, and rotate
// -output:
//  -write memory results when they appear, and rotate
//
// NOTE: not every part of data_out is wired straight to a group
//  -e.g., with 64 ports and 65 instructions, the final instruction nas no direct connection
//  -the non-wired instructions are STILL EXECUTED, as the carousel will cycle it past the sub-mems



generate

/*
// corner case where we don't need to rotate the carousel
if (TOTAL_CYCLES <= 1) begin

  // don't need to rotate the carousel
  always @(posedge clk) begin
    data_in_carousel <= data_in;
  end


  // if the group has output data ready to go, write it to the output
  for (instruction_num = 0; instruction_num < NUM_DATA_PATHS; instruction_num = instruction_num + 1) begin
    always @(posedge clk) begin
      if (group_data_valid[map_instruction_to_group(instruction_num)])
        //data_out_carousel[instruction_num*DATA_WIDTH +: DATA_WIDTH] <= group_data[instruction_num];
        data_out_carousel[instruction_num*DATA_WIDTH +: DATA_WIDTH] <= group_data[map_instruction_to_group(instruction_num)];

    end
  end

end

// general case where we need to rotate the carousel
else begin
*/






//data_in_carousel[instruction_num*FN_ARGUMENT_WIDTH +: FN_ARGUMENT_WIDTH] <= data_in[instruction_num_prev*FN_ARGUMENT_WIDTH +: FN_ARGUMENT_WIDTH]

for (instruction_num = 0; instruction_num < NUM_DATA_PATHS; instruction_num = instruction_num + 1) begin

  // every cycle the carousel shifts over one sub-memory "width"
  localparam integer instruction_num_prev = instruction_num  - NUM_SUB_MEMORY_PORTS < 0
                                          ? NUM_DATA_PATHS + instruction_num - NUM_SUB_MEMORY_PORTS // - NUM_SUB_MEMORY_PORTS
                                          : instruction_num  - NUM_SUB_MEMORY_PORTS;


  // DECEMBER 2022 CHANGES
  //assign data_in_carousel[instruction_num*FN_ARGUMENT_WIDTH +: FN_ARGUMENT_WIDTH]
  //         = data_in_valid[instruction_num_prev] & data_in_ready[instruction_num_prev]
  //         ? data_in              [instruction_num_prev*FN_ARGUMENT_WIDTH +: FN_ARGUMENT_WIDTH]
  //         : data_in_carousel_prev[instruction_num_prev*FN_ARGUMENT_WIDTH +: FN_ARGUMENT_WIDTH];
  assign data_in_carousel[instruction_num*FN_ARGUMENT_WIDTH +: FN_ARGUMENT_WIDTH]
         = data_in_valid[instruction_num_prev] & data_in_ready[instruction_num_prev]
         ? data_in[instruction_num_prev*FN_ARGUMENT_WIDTH +: FN_ARGUMENT_WIDTH]
           : stop_carousel
           ? data_in_carousel_prev[instruction_num*FN_ARGUMENT_WIDTH +: FN_ARGUMENT_WIDTH]
             : data_in_carousel_prev[instruction_num_prev*FN_ARGUMENT_WIDTH +: FN_ARGUMENT_WIDTH];









  //assign data_in_carousel[instruction_num] = data_in_valid[instruction_num_prev] & data_in_ready[instruction_num_prev]
  //                                         ? data_in[instruction_num_prev]
  //                                         : data_in_carousel_prev[instruction_num_prev];


  wire previous_valid                  = data_in_carousel_valid_prev[instruction_num_prev];
  wire previous_valid_and_being_served = previous_valid
                                       & map_instruction_to_group(instruction_num_prev) >= 0
                                       & ~group_input_processing[map_instruction_to_group(instruction_num_prev)];

  // we set the validity based on the:
  // -if we're ready to receive new data and there is data
  //  -this instruction is valid
  // -else
  //    -if this instruction can be invalidated (i.e., served)
  //     -it's made invalid only if it is valid now and being served now
  //    -else
  //     -just carry over the previous state
  // DECEMBER 2022 CHANGES
  //assign data_in_carousel_valid[instruction_num] = data_in_valid[instruction_num_prev] & data_in_ready[instruction_num_prev]
  //                                               ? 1'b1
  //                                                 : map_instruction_to_group(instruction_num_prev) >= 0
  //                                                 ? previous_valid_and_being_served
  //                                                 : previous_valid;
  assign data_in_carousel_valid[instruction_num] = data_in_valid[instruction_num_prev] & data_in_ready[instruction_num_prev]
                                                 ? 1'b1
                                                   : stop_carousel
                                                   ? 1'b0
                                                     : map_instruction_to_group(instruction_num_prev) >= 0
                                                     ? previous_valid_and_being_served
                                                       : previous_valid;
end



/*
always @(posedge clk) begin

  // state machine for rotating the input carousel
  case (state)

    // start rotating when we get new instructions
    STATE_IDLE: begin

      // if the instruction at data_in wants to read from this sub-memory
      if (data_in_valid > 0 & data_in_ready)
        data_in_carousel <= {data_in[CAROUSEL_IN_WIDTH-(FN_ARGUMENT_WIDTH*NUM_SUB_MEMORY_PORTS)-1 : 0],
                             data_in[CAROUSEL_IN_WIDTH-1                                          : CAROUSEL_IN_WIDTH-(FN_ARGUMENT_WIDTH*NUM_SUB_MEMORY_PORTS)]};
    end

    // always rotate when processing
    STATE_PROCESSING: begin
      data_in_carousel <= {data_in_carousel[CAROUSEL_IN_WIDTH-(FN_ARGUMENT_WIDTH*NUM_SUB_MEMORY_PORTS)-1 : 0],
                           data_in_carousel[CAROUSEL_IN_WIDTH-1                                          : CAROUSEL_IN_WIDTH-(FN_ARGUMENT_WIDTH*NUM_SUB_MEMORY_PORTS)]};
    end

  // don't rotate the input in other states, as we are done dealing with the input
  endcase

end
*/

for (instruction_num = 0; instruction_num < NUM_DATA_PATHS; instruction_num = instruction_num + 1) begin

  // every cycle the carousel shifts over one sub-memory "width"
  localparam integer instruction_num_prev = instruction_num  - NUM_SUB_MEMORY_PORTS < 0
                                          ? NUM_DATA_PATHS + instruction_num - NUM_SUB_MEMORY_PORTS // - NUM_SUB_MEMORY_PORTS
                                          : instruction_num  - NUM_SUB_MEMORY_PORTS;


  wire group_data_available = map_instruction_to_group(instruction_num_prev) >= 0
                            & group_data_valid[map_instruction_to_group(instruction_num_prev)];

  // DECEMBER 2022 CHANGES
  //assign data_out_carousel[instruction_num*DATA_WIDTH +: DATA_WIDTH]
  //         = group_data_available
  //         ? group_data[map_instruction_to_group(instruction_num_prev)]
  //         : data_out_carousel_prev[instruction_num_prev*DATA_WIDTH +: DATA_WIDTH];

  assign data_out_carousel[instruction_num*DATA_WIDTH +: DATA_WIDTH]
         = stop_carousel
         ? data_out_carousel_prev[instruction_num*DATA_WIDTH +: DATA_WIDTH]
           : group_data_available
           ? group_data[map_instruction_to_group(instruction_num_prev)]
           : data_out_carousel_prev[instruction_num_prev*DATA_WIDTH +: DATA_WIDTH];




  /*
  always @(posedge clk) begin

    // if there is a group assigned to this output location
    //  -NOTE: we are looking at the PREVIOUS instruction
    //if (instruction_num_prev < NUM_GROUPS) begin
    if (map_instruction_to_group(instruction_num_prev) >= 0) begin

      // if the group has output data ready to go, write it to the output
      if (group_data_valid[map_instruction_to_group(instruction_num_prev)])
        data_out_carousel[instruction_num*DATA_WIDTH +: DATA_WIDTH] <= group_data[map_instruction_to_group(instruction_num_prev)];

      // else, just rotate the data_out_carousel
      else
        data_out_carousel[instruction_num*DATA_WIDTH +: DATA_WIDTH] <= data_out_carousel[instruction_num_prev*DATA_WIDTH +: DATA_WIDTH];

    end

    // no group to assign to this location, so just rotate the data_out_carousel
    else begin
      data_out_carousel[instruction_num*DATA_WIDTH +: DATA_WIDTH] <= data_out_carousel[instruction_num_prev*DATA_WIDTH +: DATA_WIDTH];
    end


  end
  */
end
//end
endgenerate



//#############################################################################
// propagate input carousel's valid signals, updating them should an instruction be read


 // which group does this sub_mem and sub_mem_port combo belong to
function automatic integer map_sub_mem_to_group (
  input integer sub_mem,
  input integer sub_mem_port
  );
  // -we deal with the total number of ports (i.e., NUM_COMPUTE_UNITS * NUM_SUB_MEMORY_PORTS)
  // -assign each port to its own group
  // -this wraps around in the case of having more <total ports> than instructions
 //return ((sub_mem * NUM_SUB_MEMORY_PORTS) + sub_mem_port) % NUM_GROUPS;
 assert (sub_mem_port==0);
 return SUB_MEM_TO_INSTRUCTION_ASSIGNMENT[sub_mem];
endfunction


// map the given instruction to a sub_mem and sub_mem_port, then find the group they belong to
function automatic integer map_instruction_to_group (
  input integer instruction_num
  );
  // the instruction is connected to a sub memory if:
  //  -its index is given explicitly in the list
  //   OR
  //  -its index is within the range: [LIST_ENTRY_VALUE : LIST_ENTRY_VALUE + NUM_SUB_MEMORY_PORTS]
  for (int assignment_ind = 0; assignment_ind < NUM_COMPUTE_UNITS; assignment_ind++) begin
    for (int i=0; i<NUM_SUB_MEMORY_PORTS; i++) begin
      if (instruction_num == SUB_MEM_TO_INSTRUCTION_ASSIGNMENT[assignment_ind] + i)
        return map_sub_mem_to_group(assignment_ind, i);
    end
  end

  return -1;
endfunction

/*
generate
for (instruction_num = 0; instruction_num < NUM_DATA_PATHS; instruction_num = instruction_num + 1) begin

  // every cycle the carousel shifts over one sub-memory "width"
  localparam integer instruction_num_prev = instruction_num  - NUM_SUB_MEMORY_PORTS < 0
                                          ? NUM_DATA_PATHS + instruction_num - NUM_SUB_MEMORY_PORTS
                                          : instruction_num  - NUM_SUB_MEMORY_PORTS;

  // we set the validity based on the previous instruction's state
  //
  // if the previous instruction was assigned to one of the memories (i.e., there
  // is a chance it will be invalidated by being served):
  //  -instruction will be made invalid if it is already invalid or the sub-memory is processing it
  // else
  //  -just carry over the previous validity state
  wire previous_valid = state == STATE_IDLE
                      ? data_in_valid[instruction_num_prev] & data_in_ready
                      : data_in_carousel_valid_prev[instruction_num_prev];
  assign data_in_carousel_valid[instruction_num] = map_instruction_to_group(instruction_num_prev) >= 0
                                                 ? previous_valid & ~group_input_processing[map_instruction_to_group(instruction_num_prev)]
                                                 : previous_valid;

end
endgenerate
*/










//#############################################################################
// propagate output carousel's valid signals, updating them should data be written to the output carousel

//always @(posedge clk) begin
//  data_out_carousel_valid_prev = data_out_carousel_valid;
//end

generate
for (instruction_num = 0; instruction_num < NUM_DATA_PATHS; instruction_num = instruction_num + 1) begin


  // every cycle the carousel shifts over one sub-memory "width"
  localparam integer instruction_num_prev = instruction_num  - NUM_SUB_MEMORY_PORTS < 0
                                          ? NUM_DATA_PATHS + instruction_num - NUM_SUB_MEMORY_PORTS
                                          : instruction_num  - NUM_SUB_MEMORY_PORTS;



  wire being_served = map_instruction_to_group(instruction_num_prev) >= 0
                    & group_data_valid[map_instruction_to_group(instruction_num_prev)];


  // DECEMBER 2022 CHANGES
  //assign data_out_carousel_valid[instruction_num] = data_in_valid[instruction_num_prev] & data_in_ready[instruction_num_prev]
  //                                               ? 1'b0
  //                                                 : being_served
  //                                                 ? 1'b1
  //                                                 : data_out_carousel_valid_prev[instruction_num_prev];
  assign data_out_carousel_valid[instruction_num]
            = stop_carousel
            ? data_out_carousel_valid_prev[instruction_num]
              : data_in_valid[instruction_num_prev] & data_in_ready[instruction_num_prev]
              ? 1'b0
                : being_served
                ? 1'b1
                  : data_out_carousel_valid_prev[instruction_num_prev];


  /*
  always @(posedge clk) begin

    // carousel out is not valid if:
    //  -we're accepting new data at the input
    ////////////////////// OR
    ///////////////////////  -we have data to output and it was just read
    //if (state == STATE_IDLE | (data_out_valid_agg & data_out_ready)) begin
    if (data_in_valid[instruction_num_prev] & data_in_ready[instruction_num_prev]) begin
      data_out_carousel_valid[instruction_num] = 0;

    end
    else begin
      // we set the validity based on the previous instruction's state
      //
      // if the previous instruction has a group connected to it
      // AND
      // if the previous instruction has received data from one of the memories
      //  -i.e., if there is a chance it will become valid
      if (map_instruction_to_group(instruction_num_prev) >= 0) begin
        if (group_data_valid[map_instruction_to_group(instruction_num_prev)]) begin
          data_out_carousel_valid[instruction_num] <= 1'b1;
        end
        else begin
          data_out_carousel_valid[instruction_num] <= data_out_carousel_valid[instruction_num_prev];
        end
      end

      // else, get the validity state from the carousel
      else
        data_out_carousel_valid[instruction_num] <= data_out_carousel_valid[instruction_num_prev];
    end

  end
  */
end
endgenerate



//#############################################################################
// sub-memories INPUT
//  -should this sub-memory port read this instruction
//
// -slightly awkward setup as the enable signal is clocked and the address is not
//  -we therefore:
//    -set the enable NEXT CYCLE if the instruction at OUR LOCATION is valid, and meant for us
//    -set the address NOW to always point to the NEXT LOCATION
// -this saves a LOT of registers and trouble in other areas


generate
for (sub_mem = 0; sub_mem < NUM_COMPUTE_UNITS; sub_mem = sub_mem + 1) begin
  for (sub_mem_port = 0; sub_mem_port < NUM_SUB_MEMORY_PORTS; sub_mem_port = sub_mem_port + 1) begin

    // connect this sub memory to the instruction defined by the MEM_TO_INSTRUCTION_ASSIGNMENT array
    localparam integer instruction_num = SUB_MEM_TO_INSTRUCTION_ASSIGNMENT[sub_mem] + sub_mem_port;


    // address valid:
    // -ASK:
    //  -in IDLE state:
    //    -consider the newly presented data, i.e., data_in
    //   else:
    //    -consider the already registered, input carousel data
    // -ANS:
    //  -in IDLE state:
    //    -consider the newly presented data, i.e., data_in
    //   else:
    //    -consider BOTH:
    //      -the registered, input carousel data (as ANS can function like an "instant answer" ASK)
    //      -the output validity, i.e., if we have a result yet (since ASK will invalidate input we need to check if we need an output)
    if (SUB_MEM_TYPE[sub_mem] == ASK)
      assign sub_mem_addr_valid[sub_mem][sub_mem_port] = data_in_valid[instruction_num] & data_in_ready[instruction_num] //state == STATE_IDLE
                                                       ? 1'b1 //data_in_valid[instruction_num] & data_in_ready
                                                       : data_in_carousel_valid[instruction_num];
    else
      assign sub_mem_addr_valid[sub_mem][sub_mem_port] = data_in_valid[instruction_num] & data_in_ready[instruction_num] //state == STATE_IDLE
                                                       ? 1'b1 //data_in_valid[instruction_num] & data_in_ready
                                                       : data_in_carousel_valid[instruction_num] | ~data_out_carousel_valid[instruction_num];



    //assign sub_mem_addr[sub_mem][sub_mem_port]       = data_in_valid[instruction_num] & data_in_ready[instruction_num] //state == STATE_IDLE
    //                                                 ? data_in[instruction_num*FN_ARGUMENT_WIDTH +: FN_ARGUMENT_WIDTH]
    //                                                 : data_in_carousel[instruction_num*FN_ARGUMENT_WIDTH +: FN_ARGUMENT_WIDTH];
    assign sub_mem_addr[sub_mem][sub_mem_port]       = data_in_carousel[instruction_num*FN_ARGUMENT_WIDTH +: FN_ARGUMENT_WIDTH];

  end
end
endgenerate




//#############################################################################
// assign the outputs
//assign data_in_ready  = data_in_ready_r;

//assign data_out_valid_agg = data_out_carousel_valid == {NUM_DATA_PATHS{1'b1}} & state == STATE_PROCESSING;


//assign data_out = data_out_carousel;

//assign data_out = {data_out_carousel[0 +: DATA_WIDTH], data_out_carousel[NUM_DATA_PATHS-1 +: DATA_WIDTH]};


//FORWARD_START-FEED_FORWARD_END

if (FEED_FORWARD_START == -1 | FEED_FORWARD_END == -1) begin
  assign data_out = {data_out_carousel[DATA_WIDTH-1 : 0], data_out_carousel[CAROUSEL_OUT_WIDTH-1 : DATA_WIDTH]};
end


//data_out_carousel_prev[instruction_num_prev*DATA_WIDTH +: DATA_WIDTH]

generate
for (instruction_num = 0; instruction_num < NUM_DATA_PATHS; instruction_num = instruction_num + 1) begin


  // every cycle the carousel shifts over one sub-memory "width"
  localparam integer instruction_num_prev = instruction_num  - NUM_SUB_MEMORY_PORTS < 0
                                          ? NUM_DATA_PATHS + instruction_num - NUM_SUB_MEMORY_PORTS
                                          : instruction_num  - NUM_SUB_MEMORY_PORTS;

  localparam integer instruction_num_next = (instruction_num + NUM_SUB_MEMORY_PORTS) % NUM_DATA_PATHS;

  // if we are feeding the input data through to the output as well
  //  -from at is {result, input}
  //  -data is carousel shifted at the same time
  if (FEED_FORWARD_START > -1 & FEED_FORWARD_END > -1) begin

    localparam integer COMBINED_WIDTH = DATA_WIDTH + FEED_FORWARD_START - FEED_FORWARD_END;

    //assign data_out[(instruction_num+1)*COMBINED_WIDTH-1 -: COMBINED_WIDTH]
    //           = {data_out_carousel[(instruction_num_prev+1)*DATA_WIDTH-1 -: DATA_WIDTH],
    //              data_in_carousel[(instruction_num_prev_prev*FN_ARGUMENT_WIDTH)+FEED_FORWARD_START-1 : (instruction_num_prev_prev*FN_ARGUMENT_WIDTH)+FEED_FORWARD_END]};

    assign data_out[(instruction_num+1)*COMBINED_WIDTH-1 -: COMBINED_WIDTH]
               = {data_out_carousel[(instruction_num_next+1)*DATA_WIDTH-1 -: DATA_WIDTH],
                  data_in_carousel[(instruction_num_next*FN_ARGUMENT_WIDTH)+FEED_FORWARD_START-1 : (instruction_num_next*FN_ARGUMENT_WIDTH)+FEED_FORWARD_END]};

  end




  // data out allows the output carousel to fall through and be read ONCE

  //wire data_became_valid = map_instruction_to_group(instruction_num) >= 0
  //                       & group_data_valid[map_instruction_to_group(instruction_num)];
  wire data_became_valid = map_instruction_to_group(instruction_num) >= 0
                         & group_data_valid[map_instruction_to_group(instruction_num)] === 1'b1;

  // did the data in the carousel just become valid
  //wire data_became_valid = ~data_out_carousel_valid_prev[instruction_num] & data_out_carousel_valid[instruction_num];

  // -if data just became valid
  //   -latch to 1 for at least 1 cycle
  // -else
  //   -if this data was read last
  //assign data_out_valid[instruction_num] = data_became_valid
  //                                       ? 1'b1
  //                                         : data_out_valid_prev[instruction_num_prev] & data_out_ready_prev[instruction_num_prev]
  //                                         ? 1'b0
  //                                         : data_out_valid_prev[instruction_num_prev];
  assign data_out_valid[instruction_num] = data_became_valid === 1'b1
                                         ? 1'b1
                                           : data_out_valid_prev[instruction_num_prev] === 1'b1 & data_out_ready_prev[instruction_num_prev] === 1'b1
                                           ? 1'b0
                                           : data_out_valid_prev[instruction_num_prev];



  // OCTOBER 2022 CHANGE FOR HLS4ML NEURAL NETWORK
  //wire ouput_data_been_read = data_out_valid_prev[instruction_num_prev] & data_out_ready_prev[instruction_num_prev];
  //wire ouput_data_been_read = data_out_valid[instruction_num] & data_out_ready[instruction_num];
  wire ouput_data_been_read = data_out_valid[instruction_num] === 1'b1 & data_out_ready[instruction_num] === 1'b1;

  // are we ready to accept new input data
  // -if data has just been read out
  //   -ready to accept new data (hold for at least 1 cycle)
  // -else
  //   -if we were ready to accept data last cycle and did
  //     -not ready now
  //   -else
  //     -maintain current state
  //assign data_in_ready[instruction_num] = ouput_data_been_read
  //                                      ? 1'b1
  //                                        : data_in_valid_prev[instruction_num_prev] & data_in_ready_prev[instruction_num_prev]
  //                                        ? 1'b0
  //                                        : data_in_ready_prev[instruction_num_prev];
  assign data_in_ready[instruction_num] = ouput_data_been_read === 1'b1
                                        ? 1'b1
                                          : data_in_valid_prev[instruction_num_prev] === 1'b1 & data_in_ready_prev[instruction_num_prev] === 1'b1
                                          ? 1'b0
                                          : data_in_ready_prev[instruction_num_prev];

end
endgenerate


/*
//#############################################################################
// re-align the output data and valid signals for final output
//#############################################################################

// default, no misalignment
assign data_out = cycle_count == 0
                ? data_out_carousel
                : {CAROUSEL_OUT_WIDTH{1'bz}};
assign data_out_valid = cycle_count == 0
                      ? data_out_carousel_valid
                      : {NUM_DATA_PATHS{1'bz}};

// 1+ misalignments
generate
for (instruction_num = 1; instruction_num < NUM_DATA_PATHS; instruction_num = instruction_num + 1) begin

  // re-align the data out carousel for the final output
  assign data_out = cycle_count == instruction_num
                  ? {data_out_carousel[(instruction_num)*(DATA_WIDTH*NUM_SUB_MEMORY_PORTS)-1 : 0],
                     data_out_carousel[CAROUSEL_OUT_WIDTH-1 : (instruction_num)*(DATA_WIDTH*NUM_SUB_MEMORY_PORTS)]}
                  : {CAROUSEL_OUT_WIDTH{1'bz}};

  // re-align the data out carousel valid signal for the final output
  assign data_out_valid = cycle_count == instruction_num
                        ? {data_out_carousel_valid[instruction_num-1:0], data_out_carousel_valid[NUM_DATA_PATHS-1 : instruction_num]}
                        : {NUM_DATA_PATHS{1'bz}};
end
endgenerate
//#############################################################################
*/

endmodule

