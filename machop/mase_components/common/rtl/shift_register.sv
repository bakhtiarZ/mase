
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
  always_comb begin : routing
    for (int i = 0; i < BUFFER_SIZE; i++) begin
      register_bank[i] = data_in[i];
      data_out[i] = register_bank[i];    
    end
  end : routing

  always_ff @(posedge clk or posedge rst) begin
    data_in_ready <= 1'b0;
    if (rst) begin
      for (int i = 0; i < BUFFER_SIZE; i++) begin
        register_bank[i] <= '0;
        data_out_valid <= 1'b0;
        data_in_ready <= 1'b1;
      end
    end 
    else if (!data_in_ready) begin
      data_out_valid <= 1'b1;
      for (int i = BUFFER_SIZE - 1; i > 0; i--) begin
        register_bank[i] <= register_bank[i - 1];
      end
      register_bank[0] <= register_bank[BUFFER_SIZE - 1];
    end
  end

endmodule
