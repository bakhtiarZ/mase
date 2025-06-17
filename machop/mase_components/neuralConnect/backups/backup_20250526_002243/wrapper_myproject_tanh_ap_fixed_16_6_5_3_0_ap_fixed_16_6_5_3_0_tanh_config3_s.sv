/*
This module is in charge of:
  -creating multi-pool configurations
  -realigning the output data
    -by <constant> positions for cascade mode
    -by <counter> positions for non-deterministic mode
  -...
*/

`timescale 1ns / 1ps

`ifndef NUM_C
`define NUM_C 32
`endif

//DOLLARSIGN--name
module wrapper_myproject_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s #(

  NUM_COMPUTE_POOLS = 0, // numer of pools to cascade togther

  //NUM_DATA_PATHS    = 0, // number of data paths into/out of the pool
  //FN_ARGUMENT_WIDTH = 0, // total width of all function arguments
  //DATA_WIDTH        = 0, // width of each instruction's result
  NUM_DATA_INPUTS   = 0,
  INPUT_DATA_WIDTH  = 0,

  NUM_DATA_OUTPUTS  = 0,
  OUTPUT_DATA_WIDTH = 0,

  INTERMEDIATE_REGS = 0, // number of intermediate registers between pools
  OUTPUT_REGISTERS  = 0,
  MODE              = "cascade"  // "cascade" "non-deterministic"
)(
  input                          clk,
  input                          rst,

  input                          data_in_valid,
  output                         data_in_ready,
  input  [INPUT_DATA_WIDTH-1:0]  data_in [NUM_DATA_INPUTS-1:0],

  output                         data_out_valid,
  input                          data_out_ready,
  output [OUTPUT_DATA_WIDTH-1:0] data_out [NUM_DATA_OUTPUTS-1:0]

  //input  [NUM_DATA_PATHS*FN_ARGUMENT_WIDTH-1:0] data_in,
  //output [NUM_DATA_PATHS*DATA_WIDTH-1:0]        data_out
);


//#############################################################################
// convert the neural network layer data values and formats
//#############################################################################

if (NUM_DATA_INPUTS != NUM_DATA_OUTPUTS) begin
  $error("NUM_DATA_INPUTS (%d) and NUM_DATA_OUTPUTS (%d) must be the same", NUM_DATA_INPUTS, NUM_DATA_OUTPUTS);
  $fatal("NUM_DATA_INPUTS (%d) and NUM_DATA_OUTPUTS (%d) must be the same", NUM_DATA_INPUTS, NUM_DATA_OUTPUTS);
end

localparam integer FN_ARGUMENT_WIDTH = INPUT_DATA_WIDTH;
localparam integer DATA_WIDTH        = OUTPUT_DATA_WIDTH;
localparam integer NUM_DATA_PATHS    = NUM_DATA_INPUTS;

// pack the input data
wire [NUM_DATA_PATHS*FN_ARGUMENT_WIDTH-1:0] packed_data_in;
// assign packed_data_in = {>>{data_in}};

// ─── pack ────────────────────────────────────────────────────────────────
genvar unpack_idx;
generate
  for (unpack_idx = 0; unpack_idx < NUM_DATA_PATHS; unpack_idx = unpack_idx + 1) begin : PACK
    // slice out bits [unpack_idx*16 + 15 : unpack_idx*16] of the big vector
    assign packed_data_in[(unpack_idx+1)*FN_ARGUMENT_WIDTH-1 -: FN_ARGUMENT_WIDTH] = data_in[unpack_idx];
  end
endgenerate



// unpack the output data
wire [NUM_DATA_PATHS*DATA_WIDTH-1:0] unpacked_data_out;
// assign {>>{data_out}} = unpacked_data_out;
// ─── unpack ──────────────────────────────────────────────────────────────
generate
  for (unpack_idx = 0; unpack_idx < NUM_DATA_PATHS; unpack_idx = unpack_idx + 1) begin : UNPACK
    // reverse direction if you need MSB->LSB, but usually:
    assign data_out[unpack_idx] = unpacked_data_out[(unpack_idx+1)*DATA_WIDTH-1 -: DATA_WIDTH];
  end
endgenerate


//#############################################################################



localparam ASK = 0;
localparam ANS = 1;

if (MODE != "cascade" & MODE != "non-deterministic") begin
  $error("Mode must be either cascade or non-deterministic");
  $fatal("Mode must be either cascade or non-deterministic");
end

// doesn't make sense to need alignment with a known offset
if (MODE == "cascade" & OUTPUT_REGISTERS != 0) begin
  $error("Doesn't make sense to use output registers in cascade; cascade mode has a known offset");
  $fatal("Doesn't make sense to use output registers in cascade; cascade mode has a known offset");
end



localparam integer DATA_PATH_WIDTH = $clog2(NUM_DATA_PATHS);


// counts the cycle we are on when processing the data
reg [DATA_PATH_WIDTH-1:0] cycle_count = 0;


// DECEMBER 2022 CHANGES - IGNORE FEED FORWARD
//localparam integer FEED_FORWARD_START = FN_ARGUMENT_WIDTH;
localparam integer FEED_FORWARD_START = 0;
localparam integer FEED_FORWARD_END   = 0;

localparam integer INPUT_WIDTH  = NUM_DATA_PATHS*(FN_ARGUMENT_WIDTH+FEED_FORWARD_START-FEED_FORWARD_END);
localparam integer OUTPUT_WIDTH = NUM_DATA_PATHS*(DATA_WIDTH+FEED_FORWARD_START-FEED_FORWARD_END);

// compute pools
wire [NUM_DATA_PATHS-1:0]     pool_data_in_valid [NUM_COMPUTE_POOLS-1: 0];
wire [NUM_DATA_PATHS-1:0]     pool_data_in_ready [NUM_COMPUTE_POOLS-1: 0];
reg  [INPUT_WIDTH-1:0]        pool_data_in       [NUM_COMPUTE_POOLS-1: 0];
reg  [INPUT_WIDTH-1:0]        pool_data_in_prev  [NUM_COMPUTE_POOLS-1: 0];

wire [NUM_DATA_PATHS-1:0]      pool_data_out_valid [NUM_COMPUTE_POOLS-1: 0];
wire [NUM_DATA_PATHS-1:0]      pool_data_out_ready [NUM_COMPUTE_POOLS-1: 0];
//reg  [NUM_DATA_PATHS*DATA_WIDTH-1:0] pool_data_out       [NUM_COMPUTE_POOLS-1: 0];
reg  [OUTPUT_WIDTH-1:0]        pool_data_out       [NUM_COMPUTE_POOLS-1: 0];


// intermediate registers
reg [NUM_DATA_PATHS-1:0]     pool_data_in_valid_r  [NUM_COMPUTE_POOLS-1: 0][INTERMEDIATE_REGS-1:0];
reg [NUM_DATA_PATHS-1:0]     pool_data_out_ready_r [NUM_COMPUTE_POOLS-1: 0][INTERMEDIATE_REGS-1:0];
reg [INPUT_WIDTH-1:0]        pool_data_in_r        [NUM_COMPUTE_POOLS-1: 0][INTERMEDIATE_REGS-1:0];


// each intermediate register causes the cycle count to be off when re-aligning the data
//  -one cycle per intermediate register
//  -<repeated for every pool transition>
localparam integer REGISTER_CYCLE_OFFSET = INTERMEDIATE_REGS*(NUM_COMPUTE_POOLS-1);

localparam integer NUM_OUTPUT_REGISTERS  = OUTPUT_REGISTERS > DATA_PATH_WIDTH
                                         ? DATA_PATH_WIDTH
                                         : OUTPUT_REGISTERS;
localparam integer OUPUT_ALIGNMENT_WIDTH = $ceil(real'(DATA_PATH_WIDTH)/(real'(NUM_OUTPUT_REGISTERS+1)));

// output realignment registers
wire [DATA_PATH_WIDTH-1:0]           op_cycle_count      [NUM_OUTPUT_REGISTERS-1:0];
reg  [DATA_PATH_WIDTH-1:0]           op_cycle_count_r    [NUM_OUTPUT_REGISTERS-1:0];
wire                                 op_data_out_valid   [NUM_OUTPUT_REGISTERS-1:0];
reg                                  op_data_out_valid_r [NUM_OUTPUT_REGISTERS-1:0];
wire [OUTPUT_WIDTH-1:0] op_data_out         [NUM_OUTPUT_REGISTERS-1:0];
reg  [OUTPUT_WIDTH-1:0] op_data_out_r       [NUM_OUTPUT_REGISTERS-1:0];
//wire [NUM_DATA_PATHS-1:0]                        op_final_pool_data_out_ready   [NUM_OUTPUT_REGISTERS-1:0];
//reg  [NUM_DATA_PATHS-1:0]                        op_final_pool_data_out_ready_r [NUM_OUTPUT_REGISTERS-1:0];





reg [NUM_COMPUTE_POOLS-1: 0] pool_free;

localparam NUM_STATES       = 2;
localparam NUM_STATES_WIDTH = $clog2(NUM_STATES);
localparam [NUM_STATES_WIDTH-1:0]
  STATE_IDLE                     = 0,
  STATE_PROCESSING               = 1;
reg [NUM_STATES_WIDTH-1:0] state = STATE_IDLE;


initial begin
  int init_pools, init_regs;
  for (init_pools = 0; init_pools < NUM_COMPUTE_POOLS; init_pools = init_pools + 1) begin

    pool_data_in_prev[init_pools] <= 0;

    // intermediate registers
    for (init_regs = 0; init_regs < INTERMEDIATE_REGS; init_regs = init_regs + 1) begin
      pool_data_in_valid_r[init_pools][init_regs]  <= 0;
      pool_data_out_ready_r[init_pools][init_regs] <= 0;
      pool_data_in_r[init_pools][init_regs]        <= 0;
    end
  end

  // output realignment registers
  for (init_regs = 0; init_regs < NUM_OUTPUT_REGISTERS; init_regs = init_regs + 1) begin
    op_cycle_count_r[init_regs]    <= 0;
    op_data_out_valid_r[init_regs] <= 0;
    op_data_out_r[init_regs]       <= 0;
  end

  //// output realignment registers
  //for (init_regs = 0; init_regs < NUM_OUTPUT_ALIGNMENT_STAGES; init_regs = init_regs + 1) begin
  //  cycle_count_r[init_regs]               <= 0;
  //  final_pool_data_out_ready_r[init_regs] <= 0;
  //  data_out_valid_r[init_regs]            <= 0;
  //  data_out_r[init_regs]                  <= 0;
  //end

end


// global data fed into first pool
//assign pool_data_in_valid[0] = {NUM_DATA_PATHS{data_in_valid}};


//assign data_in_ready = data_in_ready_r; //pool_data_in_ready[0];

genvar data_path_num, pool_num, element_num;



integer i;

// remember data between pool stages
always @(posedge clk) begin
  for (i = 0; i < NUM_COMPUTE_POOLS; i = i + 1) begin
    pool_data_in_prev[i] <= pool_data_in[i];
  end
  //pool_data_in_prev <= pool_data_in;
end


always @(posedge clk) begin

  if (data_in_valid & data_in_ready) begin
    cycle_count <= 1;
  end
  else begin

    if (data_out_valid & data_out_ready) begin
      cycle_count <= 0;
    end
    else begin
      if (cycle_count == NUM_DATA_PATHS-1)
        cycle_count <= 0;
      else
        cycle_count <= cycle_count  + 1;
    end
  end
end



always @(posedge clk) begin
case (state)

  // waiting for input data
  STATE_IDLE: begin



    // if we have valid data and are ready to process them
    if (data_in_valid & data_in_ready) begin
      state             <= STATE_PROCESSING;

    end


  end

  STATE_PROCESSING: begin


    if (data_out_valid & data_out_ready) begin
      state <= STATE_PROCESSING;
    end


  end
endcase
end


wire all_pools_free;
if (NUM_COMPUTE_POOLS == 1)
  assign all_pools_free = pool_data_in_ready[0] == {NUM_DATA_PATHS{1'b1}};
else
  //assign all_pools_free = pool_free[NUM_COMPUTE_POOLS-1:1] == {NUM_COMPUTE_POOLS-1{1'b1}}
  assign all_pools_free = pool_free[NUM_COMPUTE_POOLS-1:0] == {NUM_COMPUTE_POOLS{1'b1}}
                        & pool_data_in_ready[0] == {NUM_DATA_PATHS{1'b1}};

always @(posedge clk) begin
  int pool_i;
  for (pool_i = 0; pool_i < NUM_COMPUTE_POOLS; pool_i = pool_i + 1) begin
    pool_free[pool_i] <= pool_data_in_ready[pool_i] == {NUM_DATA_PATHS{1'b1}};
  end
end


//#############################################################################
// FEED DATA INTO THE FIRST COMPUTE POOL
//#############################################################################

//wire ready_to_begin;

// ready for new global data when last pool is ready
//assign data_in_ready = pool_data_in_ready[NUM_COMPUTE_POOLS-1] == {NUM_DATA_PATHS{1'b1}};
assign data_in_ready = all_pools_free;// & pool_data_in_ready[0] == {NUM_DATA_PATHS{1'b1}};


// if the global data is valid & the first pool is ready to receive data
//assign ready_to_begin = data_in_valid & pool_data_in_ready[0] == {NUM_DATA_PATHS{1'b1}};



// IF data is ready to be fed through:
//  -feed it through and remember it
// ELSE
//  -remember current data
//
// DECEMBER 2022 CHANGES
//
//assign pool_data_in[0] = data_in_valid & data_in_ready
//                       ? data_in
//                       : pool_data_in_prev[0];
assign pool_data_in[0] = data_in_valid & data_in_ready
                       ? packed_data_in
                       : pool_data_in_prev[0];

assign pool_data_in_valid[0] = data_in_valid & data_in_ready
                             ? {NUM_DATA_PATHS{1'b1}}
                             : 0;
//#############################################################################





//#############################################################################
// FEED DATA BETWEEN COMPUTE POOLS
//#############################################################################

// NOTE: 0 IS ON THE RIGHT?????

// 1 pool
localparam reg FEED_FORWARD_ARG_0 [NUM_COMPUTE_POOLS-1:0] = {1'b0};
localparam reg FEED_FORWARD_ARG_1 [NUM_COMPUTE_POOLS-1:0] = {1'b0};

// 3 pools
//localparam reg FEED_FORWARD_ARG_0 [NUM_COMPUTE_POOLS-1:0] = {1'b0, 1'b1, 1'b0};
//localparam reg FEED_FORWARD_ARG_1 [NUM_COMPUTE_POOLS-1:0] = {1'b0, 1'b0, 1'b1};

wire feed_through [NUM_COMPUTE_POOLS-1:0][NUM_DATA_PATHS-1:0];
int reg_num;
// create a valid signal for each data path and invalidate it when we get
// confirmation the pool is processing it
generate
for (pool_num = 1; pool_num < NUM_COMPUTE_POOLS; pool_num = pool_num + 1) begin


  if (INTERMEDIATE_REGS == 0) begin

      // previous pool tells us if our data is valid
    assign pool_data_in_valid[pool_num] = pool_data_out_valid[pool_num-1];

    // tell previous pool if we are ready for data
    assign pool_data_out_ready[pool_num-1] = pool_data_in_ready[pool_num];


    // normal, non-fed-forward
    if (NUM_COMPUTE_POOLS == 1) begin
      if (INPUT_WIDTH > OUTPUT_WIDTH)
        assign pool_data_in[pool_num] = {{(INPUT_WIDTH-OUTPUT_WIDTH){1'b0}}, pool_data_out[pool_num-1]};
      else
        assign pool_data_in[pool_num] = pool_data_out[pool_num-1][INPUT_WIDTH-1:0];

    end

    // fed forward version
    else begin

      for (data_path_num = 0; data_path_num < NUM_DATA_PATHS; data_path_num = data_path_num + 1) begin


        localparam integer data_path_num_next = (data_path_num+1) % NUM_DATA_PATHS;

        localparam integer data_path_num_prev = data_path_num  - 1 < 0
                                              ? NUM_DATA_PATHS + data_path_num - 1
                                              : data_path_num  - 1;

        localparam integer COMBINED_WIDTH = DATA_WIDTH + FEED_FORWARD_START - FEED_FORWARD_END;


        assign pool_data_in[pool_num][(data_path_num+1)*COMBINED_WIDTH-1 -: COMBINED_WIDTH]
                   = {pool_data_out[pool_num-1][(data_path_num+1)*DATA_WIDTH-1 -: DATA_WIDTH],
                      pool_data_in[pool_num-1][(data_path_num_prev*FN_ARGUMENT_WIDTH)+FEED_FORWARD_START-1 : (data_path_num_prev*FN_ARGUMENT_WIDTH)+FEED_FORWARD_END]};




      end
    end

  end


  else begin

    // previous pool tells us if our data is valid
    assign pool_data_in_valid[pool_num] = pool_data_in_valid_r[pool_num][INTERMEDIATE_REGS-1];

    // tell previous pool if we are ready for data
    assign pool_data_out_ready[pool_num-1] = pool_data_out_ready_r[pool_num-1][INTERMEDIATE_REGS-1];

    assign pool_data_in[pool_num] = pool_data_in_r[pool_num][INTERMEDIATE_REGS-1];


    // normal, non-fed-forward version
    if (NUM_COMPUTE_POOLS == 1) begin
      always @(posedge clk) begin

        pool_data_in_valid_r[pool_num][0]    <= pool_data_out_valid[pool_num-1];
        pool_data_out_ready_r[pool_num-1][0] <= pool_data_in_ready[pool_num];

        //pool_data_in_r[pool_num][0]          <= pool_data_out[pool_num-1];


        if (INPUT_WIDTH > OUTPUT_WIDTH)
          pool_data_in_r[pool_num][0] <= {{(INPUT_WIDTH-OUTPUT_WIDTH){1'b0}}, pool_data_out[pool_num-1]};
        else
          pool_data_in_r[pool_num][0] <= pool_data_out[pool_num-1][INPUT_WIDTH-1:0];


        for (reg_num = 1; reg_num < INTERMEDIATE_REGS; reg_num = reg_num + 1) begin
          pool_data_in_valid_r[pool_num][reg_num]    <= pool_data_in_valid_r[pool_num][reg_num-1];
          pool_data_out_ready_r[pool_num-1][reg_num] <= pool_data_out_ready_r[pool_num-1][reg_num-1];
          pool_data_in_r[pool_num][reg_num]          <= pool_data_in_r[pool_num][reg_num-1];
        end

      end
    end


    // fed-forward version
    else begin
      for (data_path_num = 0; data_path_num < NUM_DATA_PATHS; data_path_num = data_path_num + 1) begin

        always @(posedge clk) begin

          if      (FEED_FORWARD_ARG_0[pool_num-1] && FEED_FORWARD_ARG_1[pool_num-1])
            pool_data_in_r[pool_num][0] <= {pool_data_out[pool_num-1], pool_data_in[pool_num-1][(data_path_num+1)*FN_ARGUMENT_WIDTH-1 -: FN_ARGUMENT_WIDTH]};
          else if (FEED_FORWARD_ARG_0[pool_num-1])
            pool_data_in_r[pool_num][0] <= {pool_data_out[pool_num-1], pool_data_in[pool_num-1][(data_path_num+1)*FN_ARGUMENT_WIDTH-FN_ARGUMENT_WIDTH/2-1 -: FN_ARGUMENT_WIDTH/2]};
          else if (FEED_FORWARD_ARG_1[pool_num-1])
            pool_data_in_r[pool_num][0] <= {pool_data_out[pool_num-1], pool_data_in[pool_num-1][(data_path_num+1)*FN_ARGUMENT_WIDTH-1 -: FN_ARGUMENT_WIDTH/2]};
          else
            pool_data_in_r[pool_num][0] <= pool_data_out[pool_num-1];

        end
      end
    end


  end


end
endgenerate


//#############################################################################





//#############################################################################
// FEED DATA OUT OF THE LAST COMPUTE POOL
//#############################################################################

if (NUM_OUTPUT_REGISTERS == 0) begin

  // ready to output global data when all the data in the final pool is ready
  assign data_out_valid = pool_data_out_valid[NUM_COMPUTE_POOLS-1] == {NUM_DATA_PATHS{1'b1}};

  // final pool's output ready signal is the global output ready signal
  assign pool_data_out_ready[NUM_COMPUTE_POOLS-1] = {NUM_DATA_PATHS{data_out_valid & data_out_ready}};

end

// SLIPSTREAM OFFSET
// C/E + (num_pools-1)
//  -assumes the same number of data-paths and response elements in each pool
localparam int RESPONSE_ELEMENTS_PER_POOL = NUM_COMPUTE_UNITS[0]/2; //16;
//localparam int CAROUSEL_OFFSET = ((NUM_DATA_PATHS/RESPONSE_ELEMENTS_PER_POOL) + (NUM_COMPUTE_POOLS-1)) % NUM_DATA_PATHS;
//localparam int CAROUSEL_OFFSET = MODE == "cascade"
//                               ? (POOL_LATENCY + (NUM_DATA_PATHS/RESPONSE_ELEMENTS_PER_POOL) + (NUM_COMPUTE_POOLS-1)) % NUM_DATA_PATHS
//                               : -1;
// october 2022: thought process on value:
//  <-1>:           because input carousel gets data values from position-1
//  <POOL_LATENCY>: cycles for actual processing (should be max of all elements?)
//  <PATHS/RESP>:   number of steps data will have to take to encounter an element (should be max if pool is sparse??)
localparam int CAROUSEL_OFFSET = MODE == "cascade"
                               ? (-1 + POOL_LATENCY + (NUM_DATA_PATHS/RESPONSE_ELEMENTS_PER_POOL)) % NUM_DATA_PATHS
                               : -1;


//#########################################################
// NO OUTPUT ALIGNMENT REGISTERS
//#########################################################

//#####################################
// re-align the output data
//  -known offset
//#####################################

if (NUM_OUTPUT_REGISTERS == 0) begin

  if (CAROUSEL_OFFSET == 0) begin
    // DECEMBER 2022 CHANGES
    //assign data_out = pool_data_out[NUM_COMPUTE_POOLS-1];
    assign unpacked_data_out = pool_data_out[NUM_COMPUTE_POOLS-1];
  end
  else if (CAROUSEL_OFFSET > 0) begin
    // DECEMBER 2022 CHANGES
    //assign data_out = {pool_data_out[NUM_COMPUTE_POOLS-1][(CAROUSEL_OFFSET*DATA_WIDTH)-1 : 0],
    assign unpacked_data_out = {pool_data_out[NUM_COMPUTE_POOLS-1][(CAROUSEL_OFFSET*DATA_WIDTH)-1 : 0],
                       pool_data_out[NUM_COMPUTE_POOLS-1][(NUM_DATA_PATHS*DATA_WIDTH)-1 : (CAROUSEL_OFFSET*DATA_WIDTH)]};
  end

end


//#####################################
// re-align the output data
//  -unknown offset
//#####################################


if (NUM_OUTPUT_REGISTERS == 0) begin

  //if (CAROUSEL_OFFSET < 0) begin
  //  // default, no misalignment
  //  assign data_out = cycle_count == 0
  //                  ? pool_data_out[NUM_COMPUTE_POOLS-1]
  //                  : {NUM_DATA_PATHS*DATA_WIDTH{1'bz}};
  //end
end

// 1+ misalignments
generate
if (NUM_OUTPUT_REGISTERS == 0) begin
  if (CAROUSEL_OFFSET < 0) begin
    for (data_path_num = 0; data_path_num < NUM_DATA_PATHS; data_path_num = data_path_num + 1) begin


      // the intermediate registers mess with the cycle count, so adjust for that here
      localparam REG_ADJUSTED_SHIFT_WIDTH = ((data_path_num+(NUM_DATA_PATHS-REGISTER_CYCLE_OFFSET)) % NUM_DATA_PATHS)*DATA_WIDTH;

      // re-align the data out carousel for the final output
      // DECEMBER 2022 CHANGES
      //assign data_out = cycle_count == data_path_num
      assign unpacked_data_out = cycle_count == data_path_num
                      ? REG_ADJUSTED_SHIFT_WIDTH == 0
                        ? pool_data_out[NUM_COMPUTE_POOLS-1]
                        : {pool_data_out[NUM_COMPUTE_POOLS-1][REG_ADJUSTED_SHIFT_WIDTH-1 : 0],
                           pool_data_out[NUM_COMPUTE_POOLS-1][(NUM_DATA_PATHS*DATA_WIDTH)-1 : REG_ADJUSTED_SHIFT_WIDTH]}
                      : {NUM_DATA_PATHS*DATA_WIDTH{1'bz}};

    end
  end
end
endgenerate





//#########################################################
// OUTPUT ALIGNMENT REGISTERS
//#########################################################



//#####################################
// re-align the output data
//  -unknown offset
//#####################################
//DATA_PATH_WIDTH
//ALIGNMENT_SECTION_WIDTH


// 1+ misalignments
//genvar data_offset_upper, data_offset_lower;
//wire [NUM_DATA_PATHS*DATA_WIDTH-1:0] data_out_r_wire;


if (NUM_OUTPUT_REGISTERS > 0) begin

  // ready to output global data when:
  //  -the alignment register data has filtered through
  //  -all the data in the final pool is ready
  assign data_out_valid = op_data_out_valid_r[NUM_OUTPUT_REGISTERS-1] & pool_data_out_valid[NUM_COMPUTE_POOLS-1] == {NUM_DATA_PATHS{1'b1}};

  // final pool's output ready signal is the global output ready signal
  assign pool_data_out_ready[NUM_COMPUTE_POOLS-1] = {NUM_DATA_PATHS{data_out_valid & data_out_ready & (pool_data_out_valid[NUM_COMPUTE_POOLS-1] == {NUM_DATA_PATHS{1'b1}}) }};

  // DECEMBER 2022 CHANGES
  //assign data_out = op_data_out_r[NUM_OUTPUT_REGISTERS-1];
  assign unpacked_data_out = op_data_out_r[NUM_OUTPUT_REGISTERS-1];
end

genvar op_reg, counter_val;

generate
if (NUM_OUTPUT_REGISTERS > 0) begin

  for (op_reg = 0; op_reg < NUM_OUTPUT_REGISTERS; op_reg = op_reg + 1) begin

    // upper and lower bounds of the cycle counter section we are interested in
    localparam integer UPPER = (op_reg+1)*OUPUT_ALIGNMENT_WIDTH > DATA_PATH_WIDTH
                             ? DATA_PATH_WIDTH
                             : (op_reg+1)*OUPUT_ALIGNMENT_WIDTH;

    localparam integer LOWER = op_reg*OUPUT_ALIGNMENT_WIDTH;

    // each stage may have a different alignment width
    // e.g., 5-bits over 3 registers = 2-bits, 2-bits, 1-bit
    localparam integer LOCAL_ALIGNMENT_WIDTH = UPPER-LOWER;

    //initial begin
    //  $display("UPPER: %d\n", UPPER);
    //  $display("LOWER: %d\n", LOWER);
    //end

    // registers for wires
    always @(posedge clk) begin
      op_cycle_count_r[op_reg]    <= op_cycle_count[op_reg];
      op_data_out_valid_r[op_reg] <= op_data_out_valid[op_reg];
      op_data_out_r[op_reg]       <= op_data_out[op_reg];
    end


    // initial stage
    if (op_reg == 0) begin

      // register the cycle counter
      assign op_cycle_count[0] = cycle_count;
      //if (UPPER-LOWER == 0)
      //  assign op_cycle_count[0] = {{OUPUT_ALIGNMENT_WIDTH-1{1'b0}}, cycle_count[UPPER-1:LOWER]};
      //else
      //  assign op_cycle_count[0] = cycle_count[UPPER-1:LOWER];

      // signal to input into register buffers
      assign op_data_out_valid[0] = pool_data_out_valid[NUM_COMPUTE_POOLS-1] == {NUM_DATA_PATHS{1'b1}};

      // if a shift of <counter_val> has occured, then shift back by that amount
      for (counter_val = 0; counter_val < 2**LOCAL_ALIGNMENT_WIDTH; counter_val = counter_val + 1) begin

        // the intermediate registers mess with the cycle count, so adjust for that here
        localparam REG_ADJUSTED_SHIFT = (counter_val+(NUM_DATA_PATHS-REGISTER_CYCLE_OFFSET)) % NUM_DATA_PATHS;

        assign op_data_out[0] = cycle_count[UPPER-1:LOWER] == counter_val
                              ? REG_ADJUSTED_SHIFT == 0
                                ?  pool_data_out[NUM_COMPUTE_POOLS-1]
                                : {pool_data_out[NUM_COMPUTE_POOLS-1][(REG_ADJUSTED_SHIFT*DATA_WIDTH)-1 : 0],
                                   pool_data_out[NUM_COMPUTE_POOLS-1][(NUM_DATA_PATHS*DATA_WIDTH)-1 : (REG_ADJUSTED_SHIFT*DATA_WIDTH)]}
                              : {NUM_DATA_PATHS*DATA_WIDTH{1'bz}};
      end

    end

    // all stages after first
    else begin

      assign op_cycle_count[op_reg]    = op_cycle_count_r[op_reg-1];
      assign op_data_out_valid[op_reg] = op_data_out_valid_r[op_reg-1];

      // if a shift of <counter_val> has occured, then shift back by that amount
      for (counter_val = 0; counter_val < 2**LOCAL_ALIGNMENT_WIDTH; counter_val = counter_val + 1) begin

        // as we are going to shift the data based on PART of the cycle count, SHIFT_AMOUNT
        // tells use what that part actually translates to
        //  -e.g., only looking at the upper 4 bits of 0001 1111, the upper part means shift by 16
        localparam integer SHIFT_AMOUNT = 2**(LOWER);

        assign op_data_out[op_reg] = op_cycle_count_r[op_reg-1][UPPER-1:LOWER] == counter_val
                                   ? counter_val == 0
                                     ?  op_data_out_r[op_reg-1]
                                     : {op_data_out_r[op_reg-1][(counter_val*SHIFT_AMOUNT*DATA_WIDTH)-1 : 0],
                                        op_data_out_r[op_reg-1][(NUM_DATA_PATHS*DATA_WIDTH)-1 : (counter_val*SHIFT_AMOUNT*DATA_WIDTH)]}
                                   : {NUM_DATA_PATHS*DATA_WIDTH{1'bz}};
      end

    end

  end
end
endgenerate


//#############################################################################


//#############################################################################
// INSTANTIATE COMPUTE POOLS
//#############################################################################


//#############################################################################
// PASTE HERE
//#############################################################################

//DOLLARSIGN--computePoolInstance
//DOLLAR SIGN --- multiPool1

// number of elements in the pool
localparam integer NUM_ELEMENTS_IN_POOL[NUM_COMPUTE_POOLS-1:0]  = {2};

// total number of call and response units
localparam integer NUM_COMPUTE_UNITS [NUM_COMPUTE_POOLS-1:0]    = {4};

// set as max element's latency
localparam integer POOL_LATENCY = 1;

// latencies of the elements in the pool
//  -element 0 is on the right
localparam integer POOL_LATENCIES[NUM_ELEMENTS_IN_POOL[0]-1:0] = {1,1};

// positions of call elements in the pool
//  -element 0 is on the right
localparam integer ELEMENT_POSITIONS[NUM_ELEMENTS_IN_POOL[0]-1:0] = {5,0};

generate
for (pool_num = 0; pool_num < NUM_COMPUTE_POOLS; pool_num = pool_num + 1) begin

  // E=2 elements
  localparam integer SUB_MEM_TO_INSTRUCTION_ASSIGNMENT [NUM_COMPUTE_UNITS[pool_num]-1:0] = {
            (POOL_LATENCIES[1]+ELEMENT_POSITIONS[1]-1) % NUM_DATA_PATHS, ELEMENT_POSITIONS[1],
            (POOL_LATENCIES[0]+ELEMENT_POSITIONS[0]-1) % NUM_DATA_PATHS, ELEMENT_POSITIONS[0]
  };

  // E=2 elements, 1 call and 1 response each
  localparam integer SUB_MEM_TYPE [NUM_COMPUTE_UNITS[pool_num]-1:0] = {
            ANS, ASK,
            ANS, ASK
  };

  // NOTE: for different pools, the only thing that changes is the module we instantiate
  wrapper_compute_pool_myproject_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s #(

    .NUM_DATA_PATHS    (NUM_DATA_PATHS),
    .FN_ARGUMENT_WIDTH (FN_ARGUMENT_WIDTH),
    .DATA_WIDTH        (DATA_WIDTH),

    // feed through input
    //.FEED_FORWARD_START (FN_ARGUMENT_WIDTH), // -1,
    //.FEED_FORWARD_END   (0),   // -1,

    //
    .NUM_COMPUTE_UNITS                 (NUM_COMPUTE_UNITS[pool_num]),
    .SUB_MEMORY_ADDRESS_WIDTH          (FN_ARGUMENT_WIDTH),

    .ELEMENT_LATENCIES                 (POOL_LATENCIES),
    .SUB_MEM_TO_INSTRUCTION_ASSIGNMENT (SUB_MEM_TO_INSTRUCTION_ASSIGNMENT),
    .SUB_MEM_TYPE                      (SUB_MEM_TYPE)
  )

  compute_pool_myproject_tanh_ap_fixed_16_6_5_3_0_ap_fixed_16_6_5_3_0_tanh_config3_s_instance (
    .clk            (clk),
    .rst            (rst),

    .data_in_valid  (pool_data_in_valid[pool_num]),
    .data_in_ready  (pool_data_in_ready[pool_num]),
    .data_in        (pool_data_in[pool_num]),

    .data_out_valid (pool_data_out_valid[pool_num]),
    .data_out_ready (pool_data_out_ready[pool_num]),
    .data_out       (pool_data_out[pool_num])
  );

end
endgenerate



/*
// number of elements in the pool
localparam integer NUM_ELEMENTS_IN_POOL[NUM_COMPUTE_POOLS-1:0]  = {2};

// total number of call and response units
localparam integer NUM_COMPUTE_UNITS [NUM_COMPUTE_POOLS-1:0]    = {2*2};

// set as max element's latency
localparam integer POOL_LATENCY = 1;

// latencies of the elements in the pool
//  -element 0 is on the right
localparam integer POOL_LATENCIES[NUM_ELEMENTS_IN_POOL[0]-1:0] = {1,1};

// positions of call elements in the pool
//  -element 0 is on the right
localparam integer ELEMENT_POSITIONS[NUM_ELEMENTS_IN_POOL[0]-1:0] = {16,0};

generate
for (pool_num = 0; pool_num < NUM_COMPUTE_POOLS; pool_num = pool_num + 1) begin

  // E=2 elements
  localparam integer SUB_MEM_TO_INSTRUCTION_ASSIGNMENT[NUM_COMPUTE_UNITS[pool_num]-1:0] = {
    (POOL_LATENCIES[1]+ELEMENT_POSITIONS[1]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[1],
    (POOL_LATENCIES[0]+ELEMENT_POSITIONS[0]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[0]
  };

  // E=2 elements, 1 call and 1 response each
  localparam integer SUB_MEM_TYPE [NUM_COMPUTE_UNITS[pool_num]-1:0] = {
    ANS, ASK,
    ANS, ASK
  };

  // NOTE: for different pools, the only thing that changes is the module we instantiate
  compute_pool #(

    .NUM_DATA_PATHS    (NUM_DATA_PATHS),
    .FN_ARGUMENT_WIDTH (FN_ARGUMENT_WIDTH),
    .DATA_WIDTH        (DATA_WIDTH),

    // feed through input
    //.FEED_FORWARD_START (FN_ARGUMENT_WIDTH), // -1,
    //.FEED_FORWARD_END   (0),   // -1,

    //
    .NUM_ELEMENTS                      (NUM_COMPUTE_UNITS[pool_num]),
    .SUB_MEMORY_ADDRESS_WIDTH          (FN_ARGUMENT_WIDTH),

    .ELEMENT_LATENCIES                 (POOL_LATENCIES),
    .SUB_MEM_TO_INSTRUCTION_ASSIGNMENT (SUB_MEM_TO_INSTRUCTION_ASSIGNMENT),
    .SUB_MEM_TYPE                      (SUB_MEM_TYPE)
  )

  compute_pool_inst (
    .clk            (clk),
    .rst            (rst),

    .data_in_valid  (pool_data_in_valid[pool_num]),
    .data_in_ready  (pool_data_in_ready[pool_num]),
    .data_in        (pool_data_in[pool_num]),

    .data_out_valid (pool_data_out_valid[pool_num]),
    .data_out_ready (pool_data_out_ready[pool_num]),
    .data_out       (pool_data_out[pool_num])
  );

end
endgenerate
*/


/*
// number of elements in the pool
localparam integer NUM_ELEMENTS_IN_POOL[NUM_COMPUTE_POOLS-1:0]  = {32};

// total number of call and response units
localparam integer NUM_COMPUTE_UNITS [NUM_COMPUTE_POOLS-1:0]    = {32*2};

// set as max element's latency
localparam integer POOL_LATENCY = 1;

// latencies of the elements in the pool
//  -element 0 is on the right
localparam integer POOL_LATENCIES[NUM_ELEMENTS_IN_POOL[0]-1:0] = {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1};

// positions of call elements in the pool
//  -element 0 is on the right
localparam integer ELEMENT_POSITIONS[NUM_ELEMENTS_IN_POOL[0]-1:0] = {31,30,29,28,27,26,25,24,23,22,21,20,19,18,17,16,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0};

generate
for (pool_num = 0; pool_num < NUM_COMPUTE_POOLS; pool_num = pool_num + 1) begin

  // E=32 elements
  localparam integer SUB_MEM_TO_INSTRUCTION_ASSIGNMENT [NUM_COMPUTE_UNITS[pool_num]-1:0] = {
    (POOL_LATENCIES[31]+ELEMENT_POSITIONS[31]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[31],
    (POOL_LATENCIES[30]+ELEMENT_POSITIONS[30]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[30],
    (POOL_LATENCIES[29]+ELEMENT_POSITIONS[29]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[29],
    (POOL_LATENCIES[28]+ELEMENT_POSITIONS[28]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[28],
    (POOL_LATENCIES[27]+ELEMENT_POSITIONS[27]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[27],
    (POOL_LATENCIES[26]+ELEMENT_POSITIONS[26]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[26],
    (POOL_LATENCIES[25]+ELEMENT_POSITIONS[25]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[25],
    (POOL_LATENCIES[24]+ELEMENT_POSITIONS[24]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[24],
    (POOL_LATENCIES[23]+ELEMENT_POSITIONS[23]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[23],
    (POOL_LATENCIES[22]+ELEMENT_POSITIONS[22]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[22],
    (POOL_LATENCIES[21]+ELEMENT_POSITIONS[21]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[21],
    (POOL_LATENCIES[20]+ELEMENT_POSITIONS[20]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[20],
    (POOL_LATENCIES[19]+ELEMENT_POSITIONS[19]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[19],
    (POOL_LATENCIES[18]+ELEMENT_POSITIONS[18]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[18],
    (POOL_LATENCIES[17]+ELEMENT_POSITIONS[17]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[17],
    (POOL_LATENCIES[16]+ELEMENT_POSITIONS[16]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[16],
    (POOL_LATENCIES[15]+ELEMENT_POSITIONS[15]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[15],
    (POOL_LATENCIES[14]+ELEMENT_POSITIONS[14]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[14],
    (POOL_LATENCIES[13]+ELEMENT_POSITIONS[13]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[13],
    (POOL_LATENCIES[12]+ELEMENT_POSITIONS[12]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[12],
    (POOL_LATENCIES[11]+ELEMENT_POSITIONS[11]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[11],
    (POOL_LATENCIES[10]+ELEMENT_POSITIONS[10]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[10],
    (POOL_LATENCIES[9]+ELEMENT_POSITIONS[9]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[9],
    (POOL_LATENCIES[8]+ELEMENT_POSITIONS[8]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[8],
    (POOL_LATENCIES[7]+ELEMENT_POSITIONS[7]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[7],
    (POOL_LATENCIES[6]+ELEMENT_POSITIONS[6]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[6],
    (POOL_LATENCIES[5]+ELEMENT_POSITIONS[5]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[5],
    (POOL_LATENCIES[4]+ELEMENT_POSITIONS[4]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[4],
    (POOL_LATENCIES[3]+ELEMENT_POSITIONS[3]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[3],
    (POOL_LATENCIES[2]+ELEMENT_POSITIONS[2]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[2],
    (POOL_LATENCIES[1]+ELEMENT_POSITIONS[1]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[1],
    (POOL_LATENCIES[0]+ELEMENT_POSITIONS[0]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[0]
  };

  // E=32 elements, 1 call and 1 response each
  localparam integer SUB_MEM_TYPE [NUM_COMPUTE_UNITS[pool_num]-1:0] = {
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK
  };

  // NOTE: for different pools, the only thing that changes is the module we instantiate
  compute_pool #(

    .NUM_DATA_PATHS    (NUM_DATA_PATHS),
    .FN_ARGUMENT_WIDTH (FN_ARGUMENT_WIDTH),
    .DATA_WIDTH        (DATA_WIDTH),

    // feed through input
    //.FEED_FORWARD_START (FN_ARGUMENT_WIDTH), // -1,
    //.FEED_FORWARD_END   (0),   // -1,

    //
    .NUM_ELEMENTS                      (NUM_COMPUTE_UNITS[pool_num]),
    .SUB_MEMORY_ADDRESS_WIDTH          (FN_ARGUMENT_WIDTH),

    .ELEMENT_LATENCIES                 (POOL_LATENCIES),
    .SUB_MEM_TO_INSTRUCTION_ASSIGNMENT (SUB_MEM_TO_INSTRUCTION_ASSIGNMENT),
    .SUB_MEM_TYPE                      (SUB_MEM_TYPE)
  )

  compute_pool_inst (
    .clk            (clk),
    .rst            (rst),

    .data_in_valid  (pool_data_in_valid[pool_num]),
    .data_in_ready  (pool_data_in_ready[pool_num]),
    .data_in        (pool_data_in[pool_num]),

    .data_out_valid (pool_data_out_valid[pool_num]),
    .data_out_ready (pool_data_out_ready[pool_num]),
    .data_out       (pool_data_out[pool_num])
  );

end
endgenerate
*/



/*
// number of elements in the pool
localparam integer NUM_ELEMENTS_IN_POOL[NUM_COMPUTE_POOLS-1:0]  = {8};

// total number of call and response units
localparam integer NUM_COMPUTE_UNITS [NUM_COMPUTE_POOLS-1:0]    = {8*2};

// set as max element's latency
localparam integer POOL_LATENCY = 1;

// latencies of the elements in the pool
//  -element 0 is on the right
localparam integer POOL_LATENCIES[NUM_ELEMENTS_IN_POOL[0]-1:0] = {1,1,1,1,1,1,1,1};

// positions of call elements in the pool
//  -element 0 is on the right
localparam integer ELEMENT_POSITIONS[NUM_ELEMENTS_IN_POOL[0]-1:0] = {14,12,10,8,6,4,2,0};

generate
for (pool_num = 0; pool_num < NUM_COMPUTE_POOLS; pool_num = pool_num + 1) begin

  // E=8 elements
  localparam integer SUB_MEM_TO_INSTRUCTION_ASSIGNMENT [NUM_COMPUTE_UNITS[pool_num]-1:0] = {
    (POOL_LATENCIES[7]+ELEMENT_POSITIONS[7]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[7],
    (POOL_LATENCIES[6]+ELEMENT_POSITIONS[6]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[6],
    (POOL_LATENCIES[5]+ELEMENT_POSITIONS[5]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[5],
    (POOL_LATENCIES[4]+ELEMENT_POSITIONS[4]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[4],
    (POOL_LATENCIES[3]+ELEMENT_POSITIONS[3]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[3],
    (POOL_LATENCIES[2]+ELEMENT_POSITIONS[2]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[2],
    (POOL_LATENCIES[1]+ELEMENT_POSITIONS[1]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[1],
    (POOL_LATENCIES[0]+ELEMENT_POSITIONS[0]) % NUM_DATA_PATHS, ELEMENT_POSITIONS[0]
  };

  // E=8 elements, 1 call and 1 response each
  localparam integer SUB_MEM_TYPE [NUM_COMPUTE_UNITS[pool_num]-1:0] = {
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK,
    ANS, ASK
  };

  // NOTE: for different pools, the only thing that changes is the module we instantiate
  compute_pool #(

    .NUM_DATA_PATHS    (NUM_DATA_PATHS),
    .FN_ARGUMENT_WIDTH (FN_ARGUMENT_WIDTH),
    .DATA_WIDTH        (DATA_WIDTH),

    // feed through input
    //.FEED_FORWARD_START (FN_ARGUMENT_WIDTH), // -1,
    //.FEED_FORWARD_END   (0),   // -1,

    //
    .NUM_ELEMENTS                      (NUM_COMPUTE_UNITS[pool_num]),
    .SUB_MEMORY_ADDRESS_WIDTH          (FN_ARGUMENT_WIDTH),

    .ELEMENT_LATENCIES                 (POOL_LATENCIES),
    .SUB_MEM_TO_INSTRUCTION_ASSIGNMENT (SUB_MEM_TO_INSTRUCTION_ASSIGNMENT),
    .SUB_MEM_TYPE                      (SUB_MEM_TYPE)
  )

  compute_pool_inst (
    .clk            (clk),

    .data_in_valid  (pool_data_in_valid[pool_num]),
    .data_in_ready  (pool_data_in_ready[pool_num]),
    .data_in        (pool_data_in[pool_num]),

    .data_out_valid (pool_data_out_valid[pool_num]),
    .data_out_ready (pool_data_out_ready[pool_num]),
    .data_out       (pool_data_out[pool_num])
  );

end
endgenerate
*/

//#############################################################################


endmodule
