`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// tb_tage_update.sv  (simulation only)
// Purpose : Unit test of tage_update (combinational). Directed cases for the
//           counter, usefulness, allocation and u-clearing rules, saturation,
//           and upd_en = 0, followed by random stimulus against an inline model.
// Ports   : none
// -----------------------------------------------------------------------------
module tb_tage_update;
  import tage_pkg::*;

  int errors = 0;

  logic                      upd_en, taken;
  logic [31:0]               upd_pc;
  logic [NUM_T:1][IDX_W-1:0] w_addr;
  logic [BASE_IDX_W-1:0]     base_waddr;
  tage_meta_t                meta;
  logic [NUM_T:1]            r_valid, r_u, we, w_valid, w_u;
  logic [NUM_T:1][TAG_W-1:0] r_tag, w_tag;
  logic [NUM_T:1][CTR_W-1:0] r_ctr, w_ctr;
  logic [1:0]                base_ctr, base_wctr;
  logic                      base_we;

  tage_update dut (
    .update_valid (upd_en), .update_pc (upd_pc), .taken (taken), .meta (meta),
    .rd_valid (r_valid), .rd_tag (r_tag), .rd_ctr (r_ctr), .rd_u (r_u), .t0_ctr (base_ctr),
    .t0_we (base_we), .t0_waddr (base_waddr), .t0_wctr (base_wctr),
    .t_we (we), .t_waddr (w_addr), .t_wvalid (w_valid), .t_wtag (w_tag), .t_wctr (w_ctr), .t_wu (w_u)
  );

  // expected outputs
  logic [NUM_T:1]            e_we, e_valid, e_u;
  logic [NUM_T:1][TAG_W-1:0] e_tag;
  logic [NUM_T:1][CTR_W-1:0] e_ctr;
  logic                      e_bwe;
  logic [1:0]                e_bctr;

  function automatic void model();
    int p, j;
    p = int'(meta.prov);
    e_we = '0; e_valid = r_valid; e_tag = r_tag; e_ctr = r_ctr; e_u = r_u;
    e_bwe = 1'b0;
    e_bctr = taken ? ((base_ctr == 3) ? base_ctr : base_ctr + 1) : ((base_ctr == 0) ? base_ctr : base_ctr - 1);
    if (!upd_en) return;
    if (p > 0) begin
      e_we[p]  = 1'b1;
      e_ctr[p] = taken ? ((r_ctr[p] == 7) ? r_ctr[p] : r_ctr[p] + 1)
                       : ((r_ctr[p] == 0) ? r_ctr[p] : r_ctr[p] - 1);
      if (meta.pred == taken && meta.alt_pred != taken) e_u[p] = 1'b1;
    end else begin
      e_bwe = 1'b1;
    end
    if (meta.pred != taken && p < 4) begin
      j = 0;
      for (int k = p + 1; k <= 4; k++) if (j == 0 && !r_u[k]) j = k;
      if (j > 0) begin
        e_we[j] = 1'b1; e_valid[j] = 1'b1; e_tag[j] = meta.tag[j];
        e_ctr[j] = taken ? 3'b100 : 3'b011; e_u[j] = 1'b0;
      end else begin
        for (int k = p + 1; k <= 4; k++) begin e_we[k] = 1'b1; e_u[k] = 1'b0; end
      end
    end
  endfunction

  task automatic check(input string what);
    model();
    #1;
    if (base_we && base_waddr !== upd_pc[BASE_IDX_W+1:2]) begin
      $display("ERROR %s: base waddr %h expected %h", what, base_waddr, upd_pc[BASE_IDX_W+1:2]);
      errors++;
    end
    for (int i = 1; i <= NUM_T; i++)
      if (we[i] && w_addr[i] !== meta.idx[i]) begin
        $display("ERROR %s: T%0d waddr %h expected %h", what, i, w_addr[i], meta.idx[i]);
        errors++;
      end
    if (base_we !== e_bwe || (e_bwe && base_wctr !== e_bctr)) begin
      $display("ERROR %s: base we %b/%b ctr %b/%b", what, base_we, e_bwe, base_wctr, e_bctr);
      errors++;
    end
    for (int i = 1; i <= NUM_T; i++) begin
      if (we[i] !== e_we[i] ||
          (e_we[i] && {w_valid[i], w_tag[i], w_ctr[i], w_u[i]} !== {e_valid[i], e_tag[i], e_ctr[i], e_u[i]})) begin
        $display("ERROR %s: T%0d we %b/%b entry %b_%h_%b_%b expected %b_%h_%b_%b", what, i,
                 we[i], e_we[i], w_valid[i], w_tag[i], w_ctr[i], w_u[i],
                 e_valid[i], e_tag[i], e_ctr[i], e_u[i]);
        errors++;
      end
    end
  endtask

  task automatic setup(int prov, int alt, bit pred, bit alt_pred, bit tk, bit [NUM_T:1] u);
    upd_en = 1'b1; taken = tk; upd_pc = 32'h0000_5A5C;
    meta = '0; meta.prov = 3'(prov); meta.alt = 3'(alt); meta.pred = pred; meta.alt_pred = alt_pred;
    meta.tag = {8'hD4, 8'hC3, 8'hB2, 8'hA1}; meta.idx = {8'h44, 8'h33, 8'h22, 8'h11};
    r_valid = '1; r_tag = {8'h04, 8'h03, 8'h02, 8'h01}; r_ctr = {3'd4, 3'd4, 3'd3, 3'd3}; r_u = u;
    base_ctr = 2'b01;
  endtask

  initial begin
    // a. prov=0 mispredict, all u=0 -> allocate T1, update base
    setup(0, 0, 0, 0, 1, 4'b0000); check("a: prov0 alloc T1");
    if (we !== 4'b0001 || w_ctr[1] !== 3'b100 || w_tag[1] !== 8'hA1 || !base_we || base_wctr !== 2'b10) begin
      $display("ERROR a"); errors++;
    end
    // a'. same, not taken -> ctr 011
    setup(0, 0, 1, 1, 0, 4'b0000); check("a': prov0 alloc T1 not-taken");
    if (w_ctr[1] !== 3'b011 || base_wctr !== 2'b00) begin $display("ERROR a'"); errors++; end
    // b. prov=2 mispredict, u3=1 u4=0 -> allocate T4
    setup(2, 1, 1, 1, 0, 4'b0100); check("b: alloc skips busy T3");
    if (we !== 4'b1010 || w_valid[4] !== 1 || w_tag[4] !== 8'hD4) begin $display("ERROR b"); errors++; end
    // c. prov=1 mispredict, u2..u4=1 -> no alloc, clear u2..u4, keep entries
    setup(1, 0, 0, 0, 1, 4'b1110); check("c: no free -> clear u");
    if (we !== 4'b1111 || w_u[4:2] !== 3'b000 || w_tag[3] !== 8'h03 || w_ctr[4] !== 3'd4) begin
      $display("ERROR c"); errors++;
    end
    // d. prov=4 mispredict -> only provider counter changes
    setup(4, 2, 1, 0, 0, 4'b0000); check("d: prov4 no alloc");
    if (we !== 4'b1000 || w_ctr[4] !== 3'd3) begin $display("ERROR d"); errors++; end
    // e. prov=3 correct, alt wrong -> u set, no alloc
    setup(3, 1, 1, 0, 1, 4'b0000); check("e: u set");
    if (we !== 4'b0100 || w_u[3] !== 1'b1 || w_ctr[3] !== 3'd5) begin $display("ERROR e"); errors++; end
    // f. prov=3 correct, alt also correct -> u unchanged
    setup(3, 1, 1, 1, 1, 4'b0000); check("f: u kept");
    if (w_u[3] !== 1'b0) begin $display("ERROR f"); errors++; end
    // g. saturation
    setup(2, 0, 1, 1, 1, 4'b0000); r_ctr[2] = 3'd7; check("g: sat 7");
    if (w_ctr[2] !== 3'd7) begin $display("ERROR g7"); errors++; end
    setup(2, 0, 0, 0, 0, 4'b0000); r_ctr[2] = 3'd0; check("g: sat 0");
    if (w_ctr[2] !== 3'd0) begin $display("ERROR g0"); errors++; end
    setup(0, 0, 1, 1, 1, 4'b0000); base_ctr = 2'b11; check("g: base sat 3");
    setup(0, 0, 0, 0, 0, 4'b0000); base_ctr = 2'b00; check("g: base sat 0");
    // h. upd_en = 0 -> no writes
    setup(0, 0, 0, 0, 1, 4'b0000); upd_en = 1'b0; check("h: idle");
    if (we !== '0 || base_we) begin $display("ERROR h"); errors++; end

    // random
    for (int n = 0; n < 50000; n++) begin
      upd_en = 1'($urandom_range(0, 7) != 0);
      taken  = 1'($urandom);
      upd_pc = $urandom;
      meta   = '0;
      meta.prov = 3'($urandom_range(0, 4));
      meta.alt  = (meta.prov == 0) ? 3'd0 : 3'($urandom_range(0, meta.prov - 1));
      meta.pred = 1'($urandom); meta.alt_pred = 1'($urandom);
      for (int i = 1; i <= NUM_T; i++) begin
        meta.tag[i] = 8'($urandom); meta.idx[i] = 8'($urandom);
        r_valid[i] = 1'($urandom); r_tag[i] = 8'($urandom); r_ctr[i] = 3'($urandom); r_u[i] = 1'($urandom);
      end
      base_ctr = 2'($urandom);
      check("random");
    end

    if (errors == 0) $display("TEST PASSED: tb_tage_update");
    else             $fatal(1, "TEST FAILED: tb_tage_update %0d errors", errors);
    $finish;
  end

endmodule
