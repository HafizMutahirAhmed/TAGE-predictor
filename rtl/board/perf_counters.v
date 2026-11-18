`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// perf_counters.v
// Purpose : Run statistics for one board run: 16-bit mispredict counters for
//           TAGE and a 16-bit branch counter. Counting stops after
//           RUN_LEN resolved branches and `done` is raised (values freeze).
// Params  : RUN_LEN  branches per run (<= 65535)
// Ports   : clk, rst               clock, synchronous clear
//           br_valid               one branch resolved this cycle
//           tage_miss              mispredict flag of that branch
//           tage_cnt               mispredict count
//           br_cnt                 branches counted so far
//           done                   br_cnt reached RUN_LEN
// -----------------------------------------------------------------------------
module perf_counters #(
  parameter RUN_LEN = 40000
) (
  input  wire        clk,
  input  wire        rst,
  input  wire        br_valid,
  input  wire        tage_miss,
  output reg  [15:0] tage_cnt,
  output reg  [15:0] br_cnt,
  output reg         done
);

  localparam [15:0] LAST = RUN_LEN - 1;

  always @(posedge clk) begin
    if (rst) begin
      tage_cnt <= 16'd0;
      br_cnt   <= 16'd0;
      done     <= 1'b0;
    end else if (br_valid && !done) begin
      br_cnt   <= br_cnt + 16'd1;
      tage_cnt <= tage_cnt + {15'd0, tage_miss};
      if (br_cnt == LAST) done <= 1'b1;
    end
  end

endmodule
