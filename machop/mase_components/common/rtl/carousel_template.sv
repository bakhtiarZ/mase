module carousel_template #(
    parameter int WIDTH_0 = 2,
    parameter int WIDTH_1 = 4,
    parameter int WIDTH_2 = 8,
    parameter int BUFFER_SIZE = 3
) (
    //TODO 
    //TODO: ADD WHEN SHIFTING, HOW TO GO BACK TO IDLE, next state should do this in always comb, but idk why it doesn't next state stays on shifting, it may be because i made the state_t supposedly 1 bit but it appears weirdly on the gtkwave. idk
    //TODO

    //data ports
    input logic [WIDTH_0 - 1 : 0] data_in_0,
    output logic [WIDTH_0 - 1 : 0] data_out_0,
    input logic  data_in_valid_0,
    output logic data_in_ready_0,
    input logic data_out_ready_0,
    output logic data_out_valid_0,
    input logic [WIDTH_1 - 1 : 0] data_in_1,
    output logic [WIDTH_1 - 1 : 0] data_out_1,
    input logic  data_in_valid_1,
    output logic data_in_ready_1,
    input logic data_out_ready_1,
    output logic data_out_valid_1,
    input logic [WIDTH_2 - 1 : 0] data_in_2,
    output logic [WIDTH_2 - 1 : 0] data_out_2,
    input logic  data_in_valid_2,
    output logic data_in_ready_2,
    input logic data_out_ready_2,
    output logic data_out_valid_2,
    
    input logic clk,
    input logic rst
);

  logic [WIDTH_0 - 1 : 0] register_0;
  logic [WIDTH_1 - 1 : 0] register_1;
  logic [WIDTH_2 - 1 : 0] register_2;
  

  logic [BUFFER_SIZE - 1 : 0] data_in_valid_arr, data_in_ready_arr, data_out_ready_arr, data_out_valid_arr;

  // packing data control signals  
  assign data_in_valid_arr[0] = data_in_valid_0;
  assign data_out_valid_0 = data_out_valid_arr[0];
  assign data_in_ready_0 = data_in_ready_arr[0];
  assign data_out_ready_arr[0] = data_out_ready_0;
    
  assign data_in_valid_arr[1] = data_in_valid_1;
  assign data_out_valid_1 = data_out_valid_arr[1];
  assign data_in_ready_1 = data_in_ready_arr[1];
  assign data_out_ready_arr[1] = data_out_ready_1;
    
  assign data_in_valid_arr[2] = data_in_valid_2;
  assign data_out_valid_2 = data_out_valid_arr[2];
  assign data_in_ready_2 = data_in_ready_arr[2];
  assign data_out_ready_arr[2] = data_out_ready_2;
  

  logic [BUFFER_SIZE - 1 : 0] ingested;
  logic [BUFFER_SIZE - 1 : 0] dispensed;
  logic [BUFFER_SIZE - 1 : 0] holding;

  typedef enum logic {
    IDLE,
    SHIFT
  } state_t;

  state_t [BUFFER_SIZE - 1 : 0] current_state, next_state;

  always_ff @(posedge clk) begin : stateMachine
    for (int i = 0; i < BUFFER_SIZE; i++) begin
      if (rst) begin
        holding[i] <= 0;
        current_state[i] <= IDLE;
      end
      else begin
        current_state[i] <= next_state[i];
      end
    end
  end

  logic all_ingest, all_dispense;
  always_comb begin : nextStateLogic
    all_ingest = &holding;
    all_dispense = !&holding ;
    for(int i=0; i < BUFFER_SIZE; i++) begin
      if (all_ingest && current_state[i] == IDLE) begin // we want this to latch
        next_state[i] = SHIFT;
      end
      else if (all_dispense && current_state[i] == SHIFT) begin
        next_state[i] = IDLE;
      end
    end
  end

  always_comb begin : data_out_connections  
      data_out_0 = register_0;  
      data_out_1 = register_1;  
      data_out_2 = register_2;
  end
  logic all_shifting;
  assign all_shifting = &current_state;
  always_ff @( posedge clk ) begin : dataFlow
    
    if (current_state[0] == IDLE) begin
      if (holding[0] == 1'b0) begin 
        data_out_valid_arr[0] <= 1'b0;
        data_in_ready_arr[0] <= 1'b1;
        if (data_in_valid_arr[0] == 1'b1 && data_in_ready_arr[0] == 1'b1) begin
          holding[0] <= 1'b1;
          register_0 <= data_in_0;
          data_in_ready_arr[0] <= 1'b0;
          data_out_valid_arr[0] <= 1'b1; 
        end
      end
      else begin 
        data_out_valid_arr[0] <= 1'b1;
        data_in_ready_arr[0] <= 1'b0;
        if (data_out_ready_arr[0] == 1'b1 && data_out_valid_arr[0] == 1'b1) begin
          holding[0] <= 1'b0;
          data_out_valid_arr[0] <= 1'b0;
          data_in_ready_arr[0] <= 1'b1;
        end
      end
    end
    
    if (current_state[1] == IDLE) begin
      if (holding[1] == 1'b0) begin 
        data_out_valid_arr[1] <= 1'b0;
        data_in_ready_arr[1] <= 1'b1;
        if (data_in_valid_arr[1] == 1'b1 && data_in_ready_arr[1] == 1'b1) begin
          holding[1] <= 1'b1;
          register_1 <= data_in_1;
          data_in_ready_arr[1] <= 1'b0;
          data_out_valid_arr[1] <= 1'b1; 
        end
      end
      else begin 
        data_out_valid_arr[1] <= 1'b1;
        data_in_ready_arr[1] <= 1'b0;
        if (data_out_ready_arr[1] == 1'b1 && data_out_valid_arr[1] == 1'b1) begin
          holding[1] <= 1'b0;
          data_out_valid_arr[1] <= 1'b0;
          data_in_ready_arr[1] <= 1'b1;
        end
      end
    end
    
    if (current_state[2] == IDLE) begin
      if (holding[2] == 1'b0) begin 
        data_out_valid_arr[2] <= 1'b0;
        data_in_ready_arr[2] <= 1'b1;
        if (data_in_valid_arr[2] == 1'b1 && data_in_ready_arr[2] == 1'b1) begin
          holding[2] <= 1'b1;
          register_2 <= data_in_2;
          data_in_ready_arr[2] <= 1'b0;
          data_out_valid_arr[2] <= 1'b1; 
        end
      end
      else begin 
        data_out_valid_arr[2] <= 1'b1;
        data_in_ready_arr[2] <= 1'b0;
        if (data_out_ready_arr[2] == 1'b1 && data_out_valid_arr[2] == 1'b1) begin
          holding[2] <= 1'b0;
          data_out_valid_arr[2] <= 1'b0;
          data_in_ready_arr[2] <= 1'b1;
        end
      end
    end
    
    if (all_shifting) begin
      data_out_valid_arr[0] <= 1'b1;
      data_in_ready_arr[0] <= 1'b0;
      data_out_valid_arr[1] <= 1'b1;
      data_in_ready_arr[1] <= 1'b0;
      data_out_valid_arr[2] <= 1'b1;
      data_in_ready_arr[2] <= 1'b0;
      
      register_0 <= register_1;
      register_1 <= register_2;
      register_2 <= register_0;
    end
  end

endmodule