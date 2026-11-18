// -----------------------------------------------------------------------------
// tage_top.v
// T0 + T1..T4 + hash + predict + update.
// meta_o / update_meta_i: flat 72-bit meta bundle, layout in tage_defines.vh.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "tage_defines.vh"

module tage_top (
  input  wire                     clk,
  input  wire                     rst_n,
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
  // Reset value 2'b10 (weakly taken) to match tage_ref. Keep both the same!
  // Flat vector: entry k at T0[2*k +: 2]
  reg  [2*(1<<BASE_IDX_W)-1:0] T0;
  wire [1:0]                   t0_rd [0:(1<<BASE_IDX_W)-1];   // read view
  wire [1:0] t0_ctr_a, t0_ctr_b;

  wire                  t0_we;
  wire [BASE_IDX_W-1:0] t0_waddr;
  wire [1:0]            t0_wctr;

  // one-hot write select; each entry has its own async-reset flip-flops;
  // reads are plain array muxes through the t0_rd view
  wire [(1<<BASE_IDX_W)-1:0] t0_wsel = {{((1<<BASE_IDX_W)-1){1'b0}}, t0_we} << t0_waddr;

  genvar e0;
  generate
    for (e0 = 0; e0 < (1<<BASE_IDX_W); e0 = e0 + 1) begin : g_t0
      always @(posedge clk or negedge rst_n) begin
        if (!rst_n)           T0[e0*2 +: 2] <= 2'b10;
        else if (t0_wsel[e0]) T0[e0*2 +: 2] <= t0_wctr;
      end
      assign t0_rd[e0] = T0[e0*2 +: 2];
    end
  endgenerate

  assign t0_ctr_a = t0_rd[pc_i[BASE_IDX_W+1:2]];
  assign t0_ctr_b = t0_rd[update_pc_i[BASE_IDX_W+1:2]];

  // ---------------- tagged tables T1..T4 ----------------
  // flat buses: table g at [(g-1)*W +: W]
  wire [4:1]         a_valid, b_valid, a_u, b_u;
  wire [4*TAG_W-1:0] a_tag, b_tag;
  wire [4*CTR_W-1:0] a_ctr, b_ctr;

  wire [4:1]         t_we, t_wvalid, t_wu;
  wire [4*IDX_W-1:0] t_waddr;
  wire [4*TAG_W-1:0] t_wtag;
  wire [4*CTR_W-1:0] t_wctr;

  genvar g;
  generate
    for (g = 1; g <= 4; g = g + 1) begin : g_tab
      tage_table #(.IDX_W(IDX_W), .TAG_W(TAG_W), .CTR_W(CTR_W)) u_tab (
        .clk(clk), .rst_n(rst_n),
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
