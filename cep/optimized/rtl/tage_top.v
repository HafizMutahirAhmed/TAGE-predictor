// -----------------------------------------------------------------------------
// tage_top.v
// T0 + T1..T4 + hash + predict + update.
// CEP optimization: all tables in LUTRAM, cleared by a clear FSM after reset;
// ready_o = 1 once all five tables are cleared.
// meta_o / update_meta_i: flat 72-bit meta bundle, layout in tage_defines.vh.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "tage_defines.vh"

module tage_top (
  input  wire                     clk,
  input  wire                     rst_n,
  output wire                     ready_o,     // 0 while the tables are being cleared after reset
  // predict
  input  wire [31:0]              pc_i,
  output wire                     pred_o,
  output wire [`TAGE_META_W-1:0]  meta_o,
  // update (one branch at a time, at resolve)
  input  wire                     update_valid_i,
  input  wire [31:0]              update_pc_i,
  input  wire                     update_taken_i,
  input  wire [`TAGE_META_W-1:0]  update_meta_i
);

  localparam IDX_W      = `TAGE_IDX_W;
  localparam TAG_W      = `TAGE_TAG_W;
  localparam CTR_W      = `TAGE_CTR_W;
  localparam BASE_IDX_W = `TAGE_BASE_IDX_W;

  // ---------------- hash (owns the GHR) ----------------
  wire [4*IDX_W-1:0] hash_idx;
  wire [4*TAG_W-1:0] hash_tag;

  tage_hash #(
    .IDX_W(IDX_W), .TAG_W(TAG_W),
    .HIST_LEN_1(`TAGE_HIST_LEN_1), .HIST_LEN_2(`TAGE_HIST_LEN_2),
    .HIST_LEN_3(`TAGE_HIST_LEN_3), .HIST_LEN_4(`TAGE_HIST_LEN_4)
  ) u_hash (
    .clk(clk), .rst_n(rst_n), .pc(pc_i),
    .idx(hash_idx), .tag(hash_tag),
    .update_en(update_valid_i), .actual_taken(update_taken_i)
  );

  // ---------------- base table T0 (1K x 2-bit) ----------------
  // CEP optimization: T0 is now a tage_table in its untagged form (LUTRAM +
  // clear FSM, 1024 clocks after reset) instead of 2048 flip-flops.
  // Reset value 2'b10 (weakly taken) to match tage_ref. Keep both the same!
  wire [1:0] t0_ctr_a, t0_ctr_b;
  wire       t0_ready;

  wire                  t0_we;
  wire [BASE_IDX_W-1:0] t0_waddr;
  wire [1:0]            t0_wctr;

  // valid/tag/u outputs are unused: the base table has none
  /* verilator lint_off PINCONNECTEMPTY */
  tage_table #(.IDX_W(BASE_IDX_W), .TAG_W(0), .CTR_W(2), .CTR_INIT(2'b10)) u_t0 (
    .clk(clk), .rst_n(rst_n), .ready(t0_ready),
    .ra_idx(pc_i[BASE_IDX_W+1:2]),
    .ra_valid(), .ra_tag(), .ra_ctr(t0_ctr_a), .ra_u(),
    .rb_idx(update_pc_i[BASE_IDX_W+1:2]),
    .rb_valid(), .rb_tag(), .rb_ctr(t0_ctr_b), .rb_u(),
    .we(t0_we), .w_idx(t0_waddr),
    .w_valid(1'b0), .w_tag(1'b0), .w_ctr(t0_wctr), .w_u(1'b0)
  );
  /* verilator lint_on PINCONNECTEMPTY */

  // ---------------- tagged tables T1..T4 ----------------
  // flat buses: table g at [(g-1)*W +: W]
  wire [4:1]         a_valid, b_valid, a_u, b_u;
  wire [4*TAG_W-1:0] a_tag, b_tag;
  wire [4*CTR_W-1:0] a_ctr, b_ctr;

  wire [4:1]         t_we, t_wvalid, t_wu;
  wire [4*IDX_W-1:0] t_waddr;
  wire [4*TAG_W-1:0] t_wtag;
  wire [4*CTR_W-1:0] t_wctr;
  wire [4:1]         t_ready;

  genvar g;
  generate
    for (g = 1; g <= 4; g = g + 1) begin : g_tab
      tage_table #(.IDX_W(IDX_W), .TAG_W(TAG_W), .CTR_W(CTR_W)) u_tab (
        .clk(clk), .rst_n(rst_n), .ready(t_ready[g]),
        .ra_idx  (hash_idx[(g-1)*IDX_W +: IDX_W]),
        .ra_valid(a_valid[g]), .ra_tag(a_tag[(g-1)*TAG_W +: TAG_W]),
        .ra_ctr  (a_ctr[(g-1)*CTR_W +: CTR_W]), .ra_u(a_u[g]),
        .rb_idx  (update_meta_i[`META_IDX_T(g)]),
        .rb_valid(b_valid[g]), .rb_tag(b_tag[(g-1)*TAG_W +: TAG_W]),
        .rb_ctr  (b_ctr[(g-1)*CTR_W +: CTR_W]), .rb_u(b_u[g]),
        .we(t_we[g]), .w_idx(t_waddr[(g-1)*IDX_W +: IDX_W]),
        .w_valid(t_wvalid[g]), .w_tag(t_wtag[(g-1)*TAG_W +: TAG_W]),
        .w_ctr(t_wctr[(g-1)*CTR_W +: CTR_W]), .w_u(t_wu[g])
      );
    end
  endgenerate

  // all five tables cleared -> predictor ready
  assign ready_o = t0_ready & (&t_ready);

  tage_predict #(.IDX_W(IDX_W), .TAG_W(TAG_W), .CTR_W(CTR_W)) u_predict (
    .t0_ctr_msb(t0_ctr_a[1]),
    .t_valid(a_valid), .t_tag(a_tag), .t_ctr(a_ctr), .t_u(a_u),
    .hash_idx(hash_idx), .hash_tag(hash_tag),
    .pred(pred_o), .meta(meta_o)               // same 72-bit layout
  );


  tage_update u_update (
    .update_valid(update_valid_i), .update_pc(update_pc_i),
    .taken(update_taken_i), .meta(update_meta_i),
    .rd_valid(b_valid), .rd_tag(b_tag), .rd_ctr(b_ctr), .rd_u(b_u),
    .t0_ctr(t0_ctr_b),
    .t0_we(t0_we), .t0_waddr(t0_waddr), .t0_wctr(t0_wctr),
    .t_we(t_we), .t_waddr(t_waddr), .t_wvalid(t_wvalid),
    .t_wtag(t_wtag), .t_wctr(t_wctr), .t_wu(t_wu)
  );

endmodule
