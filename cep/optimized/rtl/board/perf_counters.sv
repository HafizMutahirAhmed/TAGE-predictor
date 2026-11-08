`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// perf_counters.sv
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
  parameter int RUN_LEN = 40000
) (
  input  logic        clk,
  input  logic        rst,
  input  logic        br_valid,
  input  logic        tage_miss,
  output logic [15:0] tage_cnt,
  output logic [15:0] br_cnt,
  output logic        done
);

  always_ff @(posedge clk) begin
    if (rst) begin
      tage_cnt <= '0;
      br_cnt   <= '0;
      done     <= 1'b0;
    end else if (br_valid && !done) begin
      br_cnt   <= br_cnt + 16'd1;
      tage_cnt <= tage_cnt + {15'd0, tage_miss};
      if (br_cnt == 16'(RUN_LEN - 1)) done <= 1'b1;
    end
  end

endmodule
