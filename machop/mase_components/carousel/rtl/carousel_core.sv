module carousel_core #(
    parameter int WIDTH = 8,
    parameter int BUFFER_SIZE = 3
) (
    // Data ports and handshakes
    input  logic [WIDTH-1:0]        data_in      [BUFFER_SIZE],
    input  logic                    data_in_valid[BUFFER_SIZE],
    output logic                    data_in_ready[BUFFER_SIZE],
    output logic [WIDTH-1:0]        data_out     [BUFFER_SIZE],
    output logic                    data_out_valid[BUFFER_SIZE],
    input  logic                    data_out_ready[BUFFER_SIZE],

    input  logic clk,
    input  logic rst
);

  // Storage registers
  logic [WIDTH-1:0]           regs   [BUFFER_SIZE];
  logic [BUFFER_SIZE - 1 : 0] holding;

  // FSM states
  typedef enum logic { IDLE, SHIFT } state_t;
  state_t state, next_state;

  // Flags
  wire all_ingest  = &holding;
  wire all_dispense = ~|holding;

  // Sequential FSM and data operations
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      state <= IDLE;
      for (int i = 0; i < BUFFER_SIZE; i++) begin
        holding[i] <= 1'b0;
        regs[i]    <= '0;
      end
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          // Ingest or dispense each slot
          for (int i = 0; i < BUFFER_SIZE; i++) begin
            if (!holding[i] && data_in_valid[i] && data_in_ready[i]) begin
              regs[i]    <= data_in[i];
              holding[i] <= 1'b1;
            end else if (holding[i] && data_out_valid[i] && data_out_ready[i]) begin
              holding[i] <= 1'b0;
            end
          end
        end
        SHIFT: begin
          // Rotate registers
          logic [WIDTH-1:0] tmp = regs[0];
          for (int i = 0; i < BUFFER_SIZE-1; i++)
            regs[i] <= regs[i+1];
          regs[BUFFER_SIZE-1] <= tmp;
          // Clear when consumed
          for (int i = 0; i < BUFFER_SIZE; i++) begin
            if (data_out_valid[i] && data_out_ready[i])
              holding[i] <= 1'b0;
          end
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

  // Combinational handshakes & outputs
  for (genvar i = 0; i < BUFFER_SIZE; i++) begin : HANDSHAKES
    assign data_in_ready[i]   = (state == IDLE) && !holding[i];
    assign data_out_valid[i]  =  holding[i];
    assign data_out[i]        =  regs[i];
  end

endmodule
