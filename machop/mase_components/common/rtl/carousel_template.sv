module carousel_template #(
    parameter int WIDTH_0 = 2,
    parameter int WIDTH_1 = 4,
    parameter int WIDTH_2 = 8,
    parameter int BUFFER_SIZE = 3
) (
      
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

  typedef enum logic [1:0] {
    IDLE,
    SHIFT
  } state_t;

  state_t [BUFFER_SIZE - 1 : 0] current_state, next_state;

  always_ff @(posedge clk) begin : stateMachine
    for (int i = 0; i < BUFFER_SIZE; i++) begin
      if (rst)
        current_state[i] <= IDLE;
      else
        current_state[i] <= next_state[i];
    end
  end

  logic all_ingest, all_dispense;
  always_comb begin : nextStateLogic
    all_ingest = &ingested;
    all_dispense = &dispensed;
    for(int i=0; i < BUFFER_SIZE; i++) begin
      if (all_ingest && current_state == IDLE) begin // we want this to latch
        next_state[i] = SHIFT;
      end
      else if (all_dispense && current_state == SHIFT) begin
        next_state[i] = IDLE;
      end
    end
  end

  always_comb begin : data_out_connections  
      data_out_0 = register_0;  
      data_out_1 = register_1;  
      data_out_2 = register_2;
  end

  always_ff @( posedge clk ) begin : InD_Tracker
    //control
    for (int i = 0; i < BUFFER_SIZE; i++) begin
      if (data_in_valid_arr[i] == 1 && data_in_ready_arr[i] == 1 && current_state == IDLE) begin// ingestable 
        data_in_ready_arr[i] <= 1'b0;
        data_out_valid_arr[i] <= 1'b1;
        ingested[i] <= 1'b1;
      end
      else if (data_out_ready_arr[i] == 1 && ingested[i] == 1 && current_state == SHIFT) begin 
        data_in_ready_arr[i] <= 1'b1;
        data_out_valid_arr[i] <= 1'b0;
        dispensed[i] <= 1'b1;
      end
    end
  end

  always_ff @( posedge clk ) begin : dataFlow
    if (current_state == IDLE) begin
      for (int i = 0; i < BUFFER_SIZE; i++) begin
        data_out_valid_arr[i] <= 1'b0;
        data_in_ready_arr[i] <= 1'b1;
      end
      // control signals for each reg
      if (data_in_valid_arr[0] == 1'b1) begin 
        register_0 <= data_in_0;
      end
      if (data_in_valid_arr[1] == 1'b1) begin 
        register_1 <= data_in_1;
      end
      if (data_in_valid_arr[2] == 1'b1) begin 
        register_2 <= data_in_2;
      end

    end
    else if (current_state == SHIFT) begin
      for (int i = 0; i < BUFFER_SIZE; i++) begin
        data_out_valid_arr[i] <= 1'b1;
        data_in_ready_arr[i] <= 1'b0;
      end
      register_0 <= register_1;
      register_1 <= register_2;
      register_2 <= register_0;
    end
  end

endmodule