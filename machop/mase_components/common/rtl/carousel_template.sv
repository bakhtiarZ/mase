module carousel_template #(
    parameter int WIDTH_0 = 2,
    parameter int WIDTH_1 = 4,
    parameter int WIDTH_2 = 8,
    parameter int BUFFER_SIZE = 3
) (
    input logic clk,
    input logic rst,
    
    //data ports
    input logic [WIDTH_0 - 1 : 0] data_in_0,
    output logic [WIDTH_0 - 1 : 0] data_out_0,
    input logic [WIDTH_1 - 1 : 0] data_in_1,
    output logic [WIDTH_1 - 1 : 0] data_out_1,
    input logic [WIDTH_2 - 1 : 0] data_in_2,
    output logic [WIDTH_2 - 1 : 0] data_out_2,

    input logic  data_in_valid_arr [BUFFER_SIZE],
    output logic  data_in_ready_arr [BUFFER_SIZE],
    input logic  data_out_ready_arr [BUFFER_SIZE],
    output logic  data_out_valid_arr [BUFFER_SIZE]
);
  logic [WIDTH_0 - 1 : 0] register_0;
  logic [WIDTH_1 - 1 : 0] register_1;
  logic [WIDTH_2 - 1 : 0] register_2;
  

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
        current_state[i] <= next_state;
    end
  end

  logic all_ingest, all_dispense;
  always_comb begin : nextStateLogic
    all_ingest = &ingested_arr;
    all_dispense = &dispensed_arr;
    for (int i = 0; i < BUFFER_SIZE; i++) begin
      next_state = IDLE; // avoid latching
      if (all_ingest && current_state == IDLE)
        next_state = SHIFT;
      else if (all_dispense && current_state == SHIFT)
        next_state = IDLE;
    end
  end

  always_comb begin : data_out_connections  
      data_out_0 = register_0;  
      data_out_1 = register_1;  
      data_out_2 = register_2;
  end

  logic [BUFFER_SIZE - 1 : 0] ingested_arr, dispensed_arr;

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