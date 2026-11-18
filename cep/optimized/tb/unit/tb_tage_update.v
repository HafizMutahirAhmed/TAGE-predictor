`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// tb_tage_update.v  (simulation only)
// Purpose : Unit test of tage_update (combinational). Directed cases for the
//           counter, usefulness, allocation and u-clearing rules, saturation,
//           and upd_en = 0, followed by random stimulus against an inline model.
// Ports   : none
// -----------------------------------------------------------------------------
`include "tage_defines.vh"

module tb_tage_update;

  localparam NUM_T      = `TAGE_NUM_T;
  localparam IDX_W      = `TAGE_IDX_W;
  localparam TAG_W      = `TAGE_TAG_W;
  localparam CTR_W      = `TAGE_CTR_W;
  localparam BASE_IDX_W = `TAGE_BASE_IDX_W;

  integer errors = 0;

  // flat buses: table i at [(i-1)*W +: W]
  reg                      upd_en, taken;
  reg  [31:0]              upd_pc;
  wire [NUM_T*IDX_W-1:0]   w_addr;
  wire [BASE_IDX_W-1:0]    base_waddr;
  reg  [`TAGE_META_W-1:0]  meta;
  reg  [NUM_T:1]           r_valid, r_u;
  wire [NUM_T:1]           we, w_valid, w_u;
  reg  [NUM_T*TAG_W-1:0]   r_tag;
  wire [NUM_T*TAG_W-1:0]   w_tag;
  reg  [NUM_T*CTR_W-1:0]   r_ctr;
  wire [NUM_T*CTR_W-1:0]   w_ctr;
  reg  [1:0]               base_ctr;
  wire [1:0]               base_wctr;
  wire                     base_we;

  tage_update dut (
    .update_valid (upd_en), .update_pc (upd_pc), .taken (taken), .meta (meta),
    .rd_valid (r_valid), .rd_tag (r_tag), .rd_ctr (r_ctr), .rd_u (r_u), .t0_ctr (base_ctr),
    .t0_we (base_we), .t0_waddr (base_waddr), .t0_wctr (base_wctr),
    .t_we (we), .t_waddr (w_addr), .t_wvalid (w_valid), .t_wtag (w_tag), .t_wctr (w_ctr), .t_wu (w_u)
  );

  // field helpers
  `define TAG(v, i)  v[((i)-1)*TAG_W +: TAG_W]
  `define CTR(v, i)  v[((i)-1)*CTR_W +: CTR_W]
  `define IDX(v, i)  v[((i)-1)*IDX_W +: IDX_W]

  // expected outputs
  reg [NUM_T:1]          e_we, e_valid, e_u;
  reg [NUM_T*TAG_W-1:0]  e_tag;
  reg [NUM_T*CTR_W-1:0]  e_ctr;
  reg                    e_bwe;
  reg [1:0]              e_bctr;

  integer p, j, mk;
  task model;
    begin
      p = meta[`META_PROV];
      e_we = 4'b0000; e_valid = r_valid; e_tag = r_tag; e_ctr = r_ctr; e_u = r_u;
      e_bwe = 1'b0;
      e_bctr = taken ? ((base_ctr == 3) ? base_ctr : base_ctr + 1) : ((base_ctr == 0) ? base_ctr : base_ctr - 1);
      if (upd_en) begin
        if (p > 0) begin
          e_we[p]        = 1'b1;
          `CTR(e_ctr, p) = taken ? ((`CTR(r_ctr, p) == 7) ? `CTR(r_ctr, p) : `CTR(r_ctr, p) + 1)
                                 : ((`CTR(r_ctr, p) == 0) ? `CTR(r_ctr, p) : `CTR(r_ctr, p) - 1);
          if (meta[`META_PRED] == taken && meta[`META_ALT_PRED] != taken) e_u[p] = 1'b1;
        end else begin
          e_bwe = 1'b1;
        end
        if (meta[`META_PRED] != taken && p < 4) begin
          j = 0;
          for (mk = p + 1; mk <= 4; mk = mk + 1) if (j == 0 && !r_u[mk]) j = mk;
          if (j > 0) begin
            e_we[j] = 1'b1; e_valid[j] = 1'b1; `TAG(e_tag, j) = meta[`META_TAG_T(j)];
            `CTR(e_ctr, j) = taken ? 3'b100 : 3'b011; e_u[j] = 1'b0;
          end else begin
            for (mk = p + 1; mk <= 4; mk = mk + 1) begin e_we[mk] = 1'b1; e_u[mk] = 1'b0; end
          end
        end
      end
    end
  endtask

  integer i;
  task check;
    input [8*32:1] what;
    begin
      model;
      #1;
      if (base_we && base_waddr !== upd_pc[BASE_IDX_W+1:2]) begin
        $display("ERROR %0s: base waddr %h expected %h", what, base_waddr, upd_pc[BASE_IDX_W+1:2]);
        errors = errors + 1;
      end
      for (i = 1; i <= NUM_T; i = i + 1)
        if (we[i] && `IDX(w_addr, i) !== meta[`META_IDX_T(i)]) begin
          $display("ERROR %0s: T%0d waddr %h expected %h", what, i, `IDX(w_addr, i), meta[`META_IDX_T(i)]);
          errors = errors + 1;
        end
      if (base_we !== e_bwe || (e_bwe && base_wctr !== e_bctr)) begin
        $display("ERROR %0s: base we %b/%b ctr %b/%b", what, base_we, e_bwe, base_wctr, e_bctr);
        errors = errors + 1;
      end
      for (i = 1; i <= NUM_T; i = i + 1) begin
        if (we[i] !== e_we[i] ||
            (e_we[i] && {w_valid[i], `TAG(w_tag, i), `CTR(w_ctr, i), w_u[i]} !==
                        {e_valid[i], `TAG(e_tag, i), `CTR(e_ctr, i), e_u[i]})) begin
          $display("ERROR %0s: T%0d we %b/%b entry %b_%h_%b_%b expected %b_%h_%b_%b", what, i,
                   we[i], e_we[i], w_valid[i], `TAG(w_tag, i), `CTR(w_ctr, i), w_u[i],
                   e_valid[i], `TAG(e_tag, i), `CTR(e_ctr, i), e_u[i]);
          errors = errors + 1;
        end
      end
    end
  endtask

  task setup;
    input integer   prov;
    input integer   alt;
    input           pred;
    input           alt_pred;
    input           tk;
    input [NUM_T:1] u;
    begin
      upd_en = 1'b1; taken = tk; upd_pc = 32'h0000_5A5C;
      meta = {`TAGE_META_W{1'b0}};
      meta[`META_PROV] = prov; meta[`META_ALT] = alt;
      meta[`META_PRED] = pred; meta[`META_ALT_PRED] = alt_pred;
      meta[`META_TAG] = {8'hD4, 8'hC3, 8'hB2, 8'hA1}; meta[`META_IDX] = {8'h44, 8'h33, 8'h22, 8'h11};
      r_valid = 4'b1111; r_tag = {8'h04, 8'h03, 8'h02, 8'h01}; r_ctr = {3'd4, 3'd4, 3'd3, 3'd3}; r_u = u;
      base_ctr = 2'b01;
    end
  endtask

  integer n, k, pv;

  initial begin
    // a. prov=0 mispredict, all u=0 -> allocate T1, update base
    setup(0, 0, 0, 0, 1, 4'b0000); check("a: prov0 alloc T1");
    if (we !== 4'b0001 || `CTR(w_ctr, 1) !== 3'b100 || `TAG(w_tag, 1) !== 8'hA1 || !base_we || base_wctr !== 2'b10) begin
      $display("ERROR a"); errors = errors + 1;
    end
    // a'. same, not taken -> ctr 011
    setup(0, 0, 1, 1, 0, 4'b0000); check("a': prov0 alloc T1 not-taken");
    if (`CTR(w_ctr, 1) !== 3'b011 || base_wctr !== 2'b00) begin $display("ERROR a'"); errors = errors + 1; end
    // b. prov=2 mispredict, u3=1 u4=0 -> allocate T4
    setup(2, 1, 1, 1, 0, 4'b0100); check("b: alloc skips busy T3");
    if (we !== 4'b1010 || w_valid[4] !== 1 || `TAG(w_tag, 4) !== 8'hD4) begin $display("ERROR b"); errors = errors + 1; end
    // c. prov=1 mispredict, u2..u4=1 -> no alloc, clear u2..u4, keep entries
    setup(1, 0, 0, 0, 1, 4'b1110); check("c: no free -> clear u");
    if (we !== 4'b1111 || w_u[4:2] !== 3'b000 || `TAG(w_tag, 3) !== 8'h03 || `CTR(w_ctr, 4) !== 3'd4) begin
      $display("ERROR c"); errors = errors + 1;
    end
    // d. prov=4 mispredict -> only provider counter changes
    setup(4, 2, 1, 0, 0, 4'b0000); check("d: prov4 no alloc");
    if (we !== 4'b1000 || `CTR(w_ctr, 4) !== 3'd3) begin $display("ERROR d"); errors = errors + 1; end
    // e. prov=3 correct, alt wrong -> u set, no alloc
    setup(3, 1, 1, 0, 1, 4'b0000); check("e: u set");
    if (we !== 4'b0100 || w_u[3] !== 1'b1 || `CTR(w_ctr, 3) !== 3'd5) begin $display("ERROR e"); errors = errors + 1; end
    // f. prov=3 correct, alt also correct -> u unchanged
    setup(3, 1, 1, 1, 1, 4'b0000); check("f: u kept");
    if (w_u[3] !== 1'b0) begin $display("ERROR f"); errors = errors + 1; end
    // g. saturation
    setup(2, 0, 1, 1, 1, 4'b0000); `CTR(r_ctr, 2) = 3'd7; check("g: sat 7");
    if (`CTR(w_ctr, 2) !== 3'd7) begin $display("ERROR g7"); errors = errors + 1; end
    setup(2, 0, 0, 0, 0, 4'b0000); `CTR(r_ctr, 2) = 3'd0; check("g: sat 0");
    if (`CTR(w_ctr, 2) !== 3'd0) begin $display("ERROR g0"); errors = errors + 1; end
    setup(0, 0, 1, 1, 1, 4'b0000); base_ctr = 2'b11; check("g: base sat 3");
    setup(0, 0, 0, 0, 0, 4'b0000); base_ctr = 2'b00; check("g: base sat 0");
    // h. upd_en = 0 -> no writes
    setup(0, 0, 0, 0, 1, 4'b0000); upd_en = 1'b0; check("h: idle");
    if (we !== 4'b0000 || base_we) begin $display("ERROR h"); errors = errors + 1; end

    // random
    for (n = 0; n < 50000; n = n + 1) begin
      upd_en = ({$random} % 8) != 0;
      taken  = $random;
      upd_pc = $random;
      meta   = {`TAGE_META_W{1'b0}};
      pv     = {$random} % 5;
      meta[`META_PROV] = pv;
      meta[`META_ALT]  = (pv == 0) ? 3'd0 : {$random} % pv;
      meta[`META_PRED] = $random; meta[`META_ALT_PRED] = $random;
      for (k = 1; k <= NUM_T; k = k + 1) begin
        meta[`META_TAG_T(k)] = $random; meta[`META_IDX_T(k)] = $random;
        r_valid[k] = $random; `TAG(r_tag, k) = $random; `CTR(r_ctr, k) = $random; r_u[k] = $random;
      end
      base_ctr = $random;
      check("random");
    end

    if (errors == 0) $display("TEST PASSED: tb_tage_update");
    else begin
      $display("FATAL: TEST FAILED: tb_tage_update %0d errors", errors);
      $stop;
    end
    $finish;
  end

endmodule
