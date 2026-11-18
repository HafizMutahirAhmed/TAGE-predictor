`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// tb_tage_predict.v  (simulation only)
// Purpose : Unit test of tage_predict (combinational): directed cases (no hit,
//           single hit, all hit, valid=0 with matching tag) and random hit
//           patterns against an inline model of provider / alternate selection.
// Ports   : none
// -----------------------------------------------------------------------------
`include "tage_defines.vh"

module tb_tage_predict;

  localparam NUM_T = `TAGE_NUM_T;
  localparam IDX_W = `TAGE_IDX_W;
  localparam TAG_W = `TAGE_TAG_W;
  localparam CTR_W = `TAGE_CTR_W;

  integer errors = 0;

  // flat buses: table i at [(i-1)*W +: W]
  reg  [NUM_T*IDX_W-1:0]  idx;
  reg  [NUM_T*TAG_W-1:0]  tag, t_tag;
  reg  [NUM_T:1]          t_valid;
  reg  [NUM_T*CTR_W-1:0]  t_ctr;
  reg  [1:0]              base_ctr;
  wire                    pred;
  wire [`TAGE_META_W-1:0] meta;

  tage_predict #(.IDX_W(IDX_W), .TAG_W(TAG_W), .CTR_W(CTR_W)) dut (
    .t0_ctr_msb (base_ctr[1]), .t_valid (t_valid), .t_tag (t_tag), .t_ctr (t_ctr),
    .t_u (4'b0000), .hash_idx (idx), .hash_tag (tag), .pred (pred), .meta (meta)
  );

  integer ep, ea, ci;
  reg     epred, ealt;

  task check;
    input [8*24:1] what;
    begin
      ep = 0; ea = 0;
      for (ci = NUM_T; ci >= 1; ci = ci - 1) begin
        if (t_valid[ci] && t_tag[(ci-1)*TAG_W +: TAG_W] == tag[(ci-1)*TAG_W +: TAG_W]) begin
          if (ep == 0) ep = ci; else if (ea == 0) ea = ci;
        end
      end
      epred = (ep > 0) ? t_ctr[(ep-1)*CTR_W + 2] : base_ctr[1];
      ealt  = (ea > 0) ? t_ctr[(ea-1)*CTR_W + 2] : base_ctr[1];
      #1;
      if (meta[`META_PROV] != ep || meta[`META_ALT] != ea || pred !== epred ||
          meta[`META_PRED] !== epred || meta[`META_ALT_PRED] !== ealt ||
          meta[`META_IDX] !== idx || meta[`META_TAG] !== tag) begin
        $display("ERROR %0s: prov %0d/%0d alt %0d/%0d pred %b/%b alt_pred %b/%b", what,
                 meta[`META_PROV], ep, meta[`META_ALT], ea, pred, epred, meta[`META_ALT_PRED], ealt);
        errors = errors + 1;
      end
    end
  endtask

  integer i, n;

  initial begin
    // no hit -> base
    idx = {NUM_T*IDX_W{1'b0}}; tag = {8'h44, 8'h33, 8'h22, 8'h11}; t_tag = ~tag; t_valid = 4'b1111;
    t_ctr = {3'b111, 3'b111, 3'b111, 3'b111};
    base_ctr = 2'b10; check("no hit, base taken");
    base_ctr = 2'b01; check("no hit, base not taken");
    if (meta[`META_PROV] != 0 || pred != 0) begin $display("ERROR base not-taken"); errors = errors + 1; end
    // matching tag but invalid
    t_tag = tag; t_valid = 4'b0000; check("tag match, invalid");
    // single hit in each table
    for (i = 1; i <= NUM_T; i = i + 1) begin
      t_valid = 4'b0000; t_valid[i] = 1'b1;
      t_ctr = {NUM_T*CTR_W{1'b0}}; t_ctr[(i-1)*CTR_W +: CTR_W] = 3'b100; base_ctr = 2'b00;
      check("single hit");
      if (meta[`META_PROV] != i || meta[`META_ALT] != 0 || pred != 1'b1) begin
        $display("ERROR single hit T%0d", i); errors = errors + 1;
      end
    end
    // all hit: prov = 4, alt = 3
    t_valid = 4'b1111; t_ctr = {3'b011, 3'b100, 3'b000, 3'b111}; check("all hit");
    if (meta[`META_PROV] != 4 || meta[`META_ALT] != 3 || pred != 0 || meta[`META_ALT_PRED] != 1) begin
      $display("ERROR all hit"); errors = errors + 1;
    end
    // T1 + T3 hit: prov 3, alt 1
    t_tag = tag; t_tag[1*TAG_W +: TAG_W] = ~tag[1*TAG_W +: TAG_W];
    t_tag[3*TAG_W +: TAG_W] = ~tag[3*TAG_W +: TAG_W]; check("T1+T3");
    if (meta[`META_PROV] != 3 || meta[`META_ALT] != 1) begin $display("ERROR T1+T3"); errors = errors + 1; end

    // random
    for (n = 0; n < 20000; n = n + 1) begin
      for (i = 1; i <= NUM_T; i = i + 1) begin
        idx[(i-1)*IDX_W +: IDX_W]   = $random;
        tag[(i-1)*TAG_W +: TAG_W]   = $random;
        t_tag[(i-1)*TAG_W +: TAG_W] = ({$random} % 2 == 1) ? tag[(i-1)*TAG_W +: TAG_W] : $random;
        t_valid[i]                  = ({$random} % 4) != 0;
        t_ctr[(i-1)*CTR_W +: CTR_W] = $random;
      end
      base_ctr = $random;
      check("random");
    end

    if (errors == 0) $display("TEST PASSED: tb_tage_predict");
    else begin
      $display("FATAL: TEST FAILED: tb_tage_predict %0d errors", errors);
      $stop;
    end
    $finish;
  end

endmodule
