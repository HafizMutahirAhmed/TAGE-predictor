`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// tb_perf_counters.sv  (simulation only)
// Purpose : Unit test of perf_counters with a short RUN_LEN: random branch /
//           mispredict pulses against model counters, done after exactly
//           RUN_LEN branches, counters frozen afterwards, clear by reset.
// Ports   : none
// -----------------------------------------------------------------------------
module tb_perf_counters;

  localparam int RUN_LEN = 300;

  logic clk = 1'b0;
  always #5 clk = ~clk;

  int errors = 0;

  logic        rst, br_valid, tage_miss, done;
  logic [15:0] tage_cnt, br_cnt;

  perf_counters #(.RUN_LEN(RUN_LEN)) dut (
    .clk (clk), .rst (rst), .br_valid (br_valid), .tage_miss (tage_miss),
    .tage_cnt (tage_cnt), .br_cnt (br_cnt), .done (done)
  );

  int m_t, m_b;

  initial begin
    for (int pass = 0; pass < 2; pass++) begin
      rst = 1; br_valid = 0; tage_miss = 0;
      @(negedge clk); @(negedge clk);
      rst = 0;
      if (tage_cnt !== 0 || br_cnt !== 0 || done !== 0) begin
        $display("ERROR counters not cleared"); errors++;
      end
      m_t = 0; m_b = 0;
      for (int n = 0; n < 3 * RUN_LEN; n++) begin
        @(negedge clk);
        br_valid  = 1'($urandom_range(0, 2) != 0);
        tage_miss = 1'($urandom);
        @(posedge clk);
        if (br_valid && m_b < RUN_LEN) begin
          m_b++; m_t += int'(tage_miss);
        end
        #1;
        if (int'(br_cnt) != m_b || int'(tage_cnt) != m_t ||
            done !== (m_b == RUN_LEN)) begin
          $display("ERROR n=%0d br %0d/%0d tage %0d/%0d done %b", n,
                   br_cnt, m_b, tage_cnt, m_t, done);
          errors++;
        end
      end
      if (!done || br_cnt != RUN_LEN) begin $display("ERROR run did not complete"); errors++; end
    end

    if (errors == 0) $display("TEST PASSED: tb_perf_counters");
    else             $fatal(1, "TEST FAILED: tb_perf_counters %0d errors", errors);
    $finish;
  end

endmodule
