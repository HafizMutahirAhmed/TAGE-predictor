`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// tb_tage_predict.sv  (simulation only)
// Purpose : Unit test of tage_predict (combinational): directed cases (no hit,
//           single hit, all hit, valid=0 with matching tag) and random hit
//           patterns against an inline model of provider / alternate selection.
// Ports   : none
// -----------------------------------------------------------------------------
module tb_tage_predict;
  import tage_pkg::*;

  int errors = 0;

  logic [NUM_T:1][IDX_W-1:0] idx;
  logic [NUM_T:1][TAG_W-1:0] tag, t_tag;
  logic [NUM_T:1]            t_valid;
  logic [NUM_T:1][CTR_W-1:0] t_ctr;
  logic [1:0]                base_ctr;
  logic                      pred;
  tage_meta_t                meta;

  tage_predict #(.IDX_W(IDX_W), .TAG_W(TAG_W), .CTR_W(CTR_W)) dut (
    .t0_ctr_msb (base_ctr[1]), .t_valid (t_valid), .t_tag (t_tag), .t_ctr (t_ctr),
    .t_u ('0), .hash_idx (idx), .hash_tag (tag), .pred (pred), .meta (meta)
  );

  task automatic check(input string what);
    int  ep, ea;
    bit  epred, ealt;
    ep = 0; ea = 0;
    for (int i = NUM_T; i >= 1; i--) begin
      if (t_valid[i] && t_tag[i] == tag[i]) begin
        if (ep == 0) ep = i; else if (ea == 0) ea = i;
      end
    end
    epred = (ep > 0) ? t_ctr[ep][2] : base_ctr[1];
    ealt  = (ea > 0) ? t_ctr[ea][2] : base_ctr[1];
    #1;
    if (int'(meta.prov) != ep || int'(meta.alt) != ea || pred !== epred ||
        meta.pred !== epred || meta.alt_pred !== ealt || meta.idx !== idx || meta.tag !== tag) begin
      $display("ERROR %s: prov %0d/%0d alt %0d/%0d pred %b/%b alt_pred %b/%b", what,
               meta.prov, ep, meta.alt, ea, pred, epred, meta.alt_pred, ealt);
      errors++;
    end
  endtask

  initial begin
    // no hit -> base
    idx = '0; tag = {8'h44, 8'h33, 8'h22, 8'h11}; t_tag = ~tag; t_valid = '1;
    t_ctr = {3'b111, 3'b111, 3'b111, 3'b111};
    base_ctr = 2'b10; check("no hit, base taken");
    base_ctr = 2'b01; check("no hit, base not taken");
    if (meta.prov != 0 || pred != 0) begin $display("ERROR base not-taken"); errors++; end
    // matching tag but invalid
    t_tag = tag; t_valid = '0; check("tag match, invalid");
    // single hit in each table
    for (int i = 1; i <= NUM_T; i++) begin
      t_valid = '0; t_valid[i] = 1'b1; t_ctr = '0; t_ctr[i] = 3'b100; base_ctr = 2'b00;
      check($sformatf("single hit T%0d", i));
      if (meta.prov != 3'(i) || meta.alt != 0 || pred != 1'b1) begin
        $display("ERROR single hit T%0d", i); errors++;
      end
    end
    // all hit: prov = 4, alt = 3
    t_valid = '1; t_ctr = {3'b011, 3'b100, 3'b000, 3'b111}; check("all hit");
    if (meta.prov != 4 || meta.alt != 3 || pred != 0 || meta.alt_pred != 1) begin
      $display("ERROR all hit"); errors++;
    end
    // T1 + T3 hit: prov 3, alt 1
    t_tag = tag; t_tag[2] = ~tag[2]; t_tag[4] = ~tag[4]; check("T1+T3");
    if (meta.prov != 3 || meta.alt != 1) begin $display("ERROR T1+T3"); errors++; end

    // random
    for (int n = 0; n < 20000; n++) begin
      for (int i = 1; i <= NUM_T; i++) begin
        idx[i]     = 8'($urandom);
        tag[i]     = 8'($urandom);
        t_tag[i]   = ($urandom_range(0, 1) == 1) ? tag[i] : 8'($urandom);
        t_valid[i] = 1'($urandom_range(0, 3) != 0);
        t_ctr[i]   = 3'($urandom);
      end
      base_ctr = 2'($urandom);
      check("random");
    end

    if (errors == 0) $display("TEST PASSED: tb_tage_predict");
    else             $fatal(1, "TEST FAILED: tb_tage_predict %0d errors", errors);
    $finish;
  end

endmodule
