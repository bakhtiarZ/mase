
module shift_register #(
    parameter WIDTH = 8,
    parameter BUFFER_SIZE = 16
) (
    input logic clk,
    input logic rst,

    input logic [WIDTH-1 : 0] data_in [BUFFER_SIZE - 1 : 0],
    input logic data_in_valid,
    output logic data_in_ready,

    input logic data_out_ready,
    output logic data_out_valid,
    output logic [WIDTH-1 : 0] data_out[BUFFER_SIZE - 1 : 0]
);

  logic [WIDTH-1 : 0] register_bank [BUFFER_SIZE - 1 : 0];
  localparam SHIFT_COUNTER_SIZE = $clog2(BUFFER_SIZE);
  logic [SHIFT_COUNTER_SIZE-1 : 0] shift_counter;
  always_comb begin : routing
    for (int i = 0; i < BUFFER_SIZE; i++) begin
      data_out[i] = register_bank[i];    
    end
  end : routing

  always_ff @(posedge clk) begin
    if (rst) begin
      for (int i = 0; i < BUFFER_SIZE; i++) begin
        register_bank[i] <= '0;
      end
      shift_counter <= SHIFT_COUNTER_SIZE;
      data_out_valid <= 1'b0;
      data_in_ready <= 1'b1;
    end 
    else if (data_in_ready && data_in_valid) begin // its been reset and now accepts data if its 
      for (int i = 0; i < BUFFER_SIZE; i++) begin
        register_bank[i] <= data_in[i];
        data_in_ready <= 1'b0;
      end
    end
    else if (!data_in_ready) begin // shifting
    
      data_out_valid <= 1'b1;
      shift_counter <= shift_counter - 1;
      for (int i = BUFFER_SIZE - 1; i > 0; i--) begin
        register_bank[i - 1] <= register_bank[i];
      end
      register_bank[BUFFER_SIZE - 1] <= register_bank[0];
    end
  end

endmodule
