module carousel_core_always_shift #(
    parameter int WIDTH = 8,
    parameter int BUFFER_SIZE = 3
) (
    input  logic [WIDTH-1:0]        data_in      [BUFFER_SIZE],
    input  logic                    data_in_valid[BUFFER_SIZE],
    output logic                    data_in_ready[BUFFER_SIZE],

    output logic [WIDTH-1:0]        data_out     [BUFFER_SIZE],
    output logic                    data_out_valid[BUFFER_SIZE],
    input  logic                    data_out_ready[BUFFER_SIZE],

    input  logic clk,
    input  logic rst
);

  // // Storage and occupancy
  // logic [WIDTH-1:0] regs   [BUFFER_SIZE];
  // logic [WIDTH-1:0] next_regs [BUFFER_SIZE];
  // logic [BUFFER_SIZE-1:0] holding;
  // logic [BUFFER_SIZE-1:0] next_holding;

  // Combine data + valid into a packed struct for shifting
  typedef struct packed {
    logic valid;
    logic [WIDTH-1:0] data;
  } entry_t;

  entry_t entries   [BUFFER_SIZE];
  entry_t next_entries   [BUFFER_SIZE];

  // Sequential shift + ingest + dispense logic
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      for (int i = 0; i < BUFFER_SIZE; i++) begin
        // regs[i]    <= '0;
        // holding[i] <= 1'b0;
        entries[i].valid <= 1'b0;
        entries[i].data  <= '0;
      end
    end
    else begin
      // update state
      for (int i = 0; i < BUFFER_SIZE; i++) begin
        // regs[i]    <= next_regs[i];
        // holding[i] <= next_holding[i];
        entries[i] <= next_entries[i];
      end
    end
  end
  
  always_comb begin : nextStates
    // compute next holding and register values
    for (int i = 0; i < BUFFER_SIZE; i++) begin
      // ingest if empty and valid
      // if (!holding[i] && data_in_valid[i] && data_in_ready[i]) begin
      if (!entries[i].valid && data_in_valid[i]) begin
        // next_regs[i]    = data_in[i];
        // next_holding[i] = 1'b1;
        next_entries[i].data = data_in[i];
        next_entries[i].valid = 1'b1;
      end else begin
        // shift from previous slot
        int prev = (i + 1 == BUFFER_SIZE) ? 0 : i + 1;
        // next_regs[i]    = regs[prev];
        next_entries[i]    = entries[prev];
        // clear on output consume
        // if (holding[i] && data_out_valid[i] && data_out_ready[i])
        //   next_holding[i] = 1'b0;
        // else
        //   next_holding[i] = holding[i];
        if (entries[prev].valid && data_out_valid[prev] && data_out_ready[prev])
          next_entries[i].valid = 1'b0;
        else
          next_entries[i].valid = entries[prev].valid;
      end
    end
  end

  // // Combinational handshakes and outputs
  // for (genvar i = 0; i < BUFFER_SIZE; i++) begin : HANDSHAKES
  //   assign data_in_ready[i]   = !holding[i];
  //   assign data_out_valid[i]  =  holding[i];
  //   assign data_out[i]        =  regs[i];
  // end
  // Combinational outputs from struct fields
  
  for (genvar j = 0; j < BUFFER_SIZE; j++) begin : OUT_HANDSHAKE
    assign data_in_ready[j]   = !entries[j].valid;
    assign data_out_valid[j]  =  entries[j].valid;
    assign data_out[j]        =  entries[j].data;
  end

endmodule
