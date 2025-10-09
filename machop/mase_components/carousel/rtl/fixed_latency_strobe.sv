`timescale 1ns / 1ps
module fixed_latency_strobe #(
  int unsigned LATENCY = 1   // 1 => pulse every cycle
) (
  input  logic clk,
  input  logic rst,           // sync reset, active-high
  output logic data_out_valid // 1-cycle pulse
);

generate
  if (LATENCY == 0) begin : g_lat0
    // Degenerate case: "every 0 clocks" => always valid
    assign data_out_valid = 1'b1;
  end else begin : g_latN
    localparam int COUNTER_W = (LATENCY <= 1) ? 1 : $clog2(LATENCY);
    logic [COUNTER_W-1:0] count;

    always_ff @(posedge clk) begin
      if (rst) begin
        count           <= '0;
        data_out_valid  <= 1'b0;
      end else begin
        // Pulse when count hits LATENCY-1, then wrap
        if (count == LATENCY-1) begin
          data_out_valid <= 1'b1;
          count          <= '0;
        end else begin
          data_out_valid <= 1'b0;
          count          <= count + 1'b1;
        end
      end
    end
  end
endgenerate
endmodule
