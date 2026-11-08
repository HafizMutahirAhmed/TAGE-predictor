`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// tb_waves.sv  (simulation only, CEP waveforms)
// Small directed run of tage_top that dumps waves.vcd with the signals needed
// for the report figures:
//   W1  reset -> clear FSM (clr_idx counting) -> ready_o rises after 1024 clocks
//   W2  one branch: pc_i -> pred_o / meta_o in the same cycle (cycle A),
//       then update_valid_i with the saved meta (cycle B), GHR shifts
//   W3  a misprediction: tage_update allocates a new entry in T1 (t_we[1])
// Same 2-cycle protocol as nexys7_top.
// -----------------------------------------------------------------------------
module tb_waves;
  import tage_pkg::*;

  logic clk = 1'b0;
  always #10 clk = ~clk;                     // 50 MHz, like the board

  logic        rst_n, ready;
  logic [31:0] pc, upd_pc;
  logic        upd_en, upd_taken, pred;
  tage_meta_t  meta, upd_meta;

  tage_top dut (
    .clk(clk), .rst_n(rst_n), .ready_o(ready),
    .pc_i(pc), .pred_o(pred), .meta_o(meta),
    .update_valid_i(upd_en), .update_pc_i(upd_pc),
    .update_taken_i(upd_taken), .update_meta_i(upd_meta)
  );

  // flat copies of internal signals so the VCD stays small
  logic        t0_clearing, t1_clearing;
  logic [9:0]  t0_clr_idx;
  logic [7:0]  t1_clr_idx;
  logic [31:0] ghr;
  logic [2:0]  prov, alt;
  logic [7:0]  idx1, tag1;
  logic [4:1]  t_we, hit;
  logic        t0_we, t1_wvalid, mispredict;
  logic [2:0]  t1_wctr;
  logic [7:0]  t1_wtag;
  assign t0_clearing = dut.u_t0.clearing;
  assign t0_clr_idx  = dut.u_t0.clr_idx;
  assign t1_clearing = dut.g_tab[1].u_tab.clearing;
  assign t1_clr_idx  = dut.g_tab[1].u_tab.clr_idx;
  assign ghr         = dut.u_hash.ghr;
  assign prov        = meta.prov;
  assign alt         = meta.alt;
  assign idx1        = meta.idx[1];
  assign tag1        = meta.tag[1];
  assign hit         = dut.u_predict.hit;
  assign t_we        = dut.t_we;
  assign t0_we       = dut.t0_we;
  assign t1_wvalid   = dut.t_wvalid[1];
  assign t1_wctr     = dut.t_wctr[1];
  assign t1_wtag     = dut.t_wtag[1];
  assign mispredict  = upd_en && (upd_meta.pred != upd_taken);

  task automatic branch(input logic [31:0] bpc, input logic taken);
    @(negedge clk);                          // cycle A: predict
    upd_en = 1'b0; pc = bpc;
    #1 upd_meta = meta;                      // save the receipt
    @(negedge clk);                          // cycle B: update
    upd_en = 1'b1; upd_pc = bpc; upd_taken = taken; pc = '0;
  endtask

  initial begin
    $dumpfile("waves.vcd");
    $dumpvars(1, tb_waves);
    rst_n = 1'b0; pc = '0; upd_pc = '0; upd_en = 1'b0; upd_taken = 1'b0; upd_meta = '0;
    repeat (3) @(negedge clk);
    rst_n = 1'b1;
    wait (ready === 1'b1);
    @(negedge clk); @(negedge clk);
    // A: T0 starts at 10 (weakly taken) -> predicts taken, correct
    branch(32'h0000_1040, 1'b1);
    // B: predicts taken but is not taken -> misprediction -> allocate in T1
    branch(32'h0000_2000, 1'b0);
    branch(32'h0000_1040, 1'b1);
    branch(32'h0000_2000, 1'b0);
    @(negedge clk); upd_en = 1'b0;
    repeat (3) @(negedge clk);
    $display("waves.vcd written");
    $finish;
  end
endmodule
