module carousel_template #(
    parameter int WIDTH_0 = 2,
    parameter int WIDTH_1 = 4,
    parameter int WIDTH_2 = 8,
    parameter int BUFFER_SIZE = 3
) (
    // Data ports and handshakes
    input  logic [WIDTH_0-1:0] data_in_0,
    input  logic             data_in_valid_0,
    output logic             data_in_ready_0,
    output logic [WIDTH_0-1:0] data_out_0,
    output logic             data_out_valid_0,
    input  logic             data_out_ready_0,

    input  logic [WIDTH_1-1:0] data_in_1,
    input  logic             data_in_valid_1,
    output logic             data_in_ready_1,
    output logic [WIDTH_1-1:0] data_out_1,
    output logic             data_out_valid_1,
    input  logic             data_out_ready_1,

    input  logic [WIDTH_2-1:0] data_in_2,
    input  logic             data_in_valid_2,
    output logic             data_in_ready_2,
    output logic [WIDTH_2-1:0] data_out_2,
    output logic             data_out_valid_2,
    input  logic             data_out_ready_2,

    input  logic clk,
    input  logic rst
);

  // Parameterized storage registers
  logic [WIDTH_0-1:0] reg0;
  logic [WIDTH_1-1:0] reg1;
  logic [WIDTH_2-1:0] reg2;

  // Array of occupancy flags
  logic [BUFFER_SIZE-1:0] holding;

  // FSM states
  typedef enum logic { IDLE, SHIFT } state_t;
  state_t state, next_state;

  // Ingestion/dispense flags
  wire all_ingest  = &holding;
  wire all_dispense = ~|holding;

  // Sequential FSM and data operations
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      state   <= IDLE;
      holding <= '0;
      reg0    <= '0;
      reg1    <= '0;
      reg2    <= '0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          // Ingest when free
          if (data_in_valid_0 && data_in_ready_0) begin
            reg0    <= data_in_0;
            holding[0] <= 1'b1;
          end
          if (data_in_valid_1 && data_in_ready_1) begin
            reg1    <= data_in_1;
            holding[1] <= 1'b1;
          end
          if (data_in_valid_2 && data_in_ready_2) begin
            reg2    <= data_in_2;
            holding[2] <= 1'b1;
          end
          // Dispense if requested
          if (data_out_valid_0 && data_out_ready_0) holding[0] <= 1'b0;
          if (data_out_valid_1 && data_out_ready_1) holding[1] <= 1'b0;
          if (data_out_valid_2 && data_out_ready_2) holding[2] <= 1'b0;
        end

        SHIFT: begin
          // Rotate all items
          logic [WIDTH_0-1:0] tmp0 = reg0;
          reg0 <= reg1;
          reg1 <= reg2;
          reg2 <= tmp0;
          // Clear each as it is consumed
          if (data_out_valid_0 && data_out_ready_0) holding[0] <= 1'b0;
          if (data_out_valid_1 && data_out_ready_1) holding[1] <= 1'b0;
          if (data_out_valid_2 && data_out_ready_2) holding[2] <= 1'b0;
        end
      endcase
    end
  end

  // FSM next-state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE:  if (all_ingest)    next_state = SHIFT;
      SHIFT: if (all_dispense)  next_state = IDLE;
    endcase
  end

  // Combinational handshakes and outputs
  assign data_in_ready_0   = (state == IDLE) && !holding[0];
  assign data_out_valid_0  =  holding[0];
  assign data_out_0        =  reg0;

  assign data_in_ready_1   = (state == IDLE) && !holding[1];
  assign data_out_valid_1  =  holding[1];
  assign data_out_1        =  reg1;

  assign data_in_ready_2   = (state == IDLE) && !holding[2];
  assign data_out_valid_2  =  holding[2];
  assign data_out_2        =  reg2;

endmodule
