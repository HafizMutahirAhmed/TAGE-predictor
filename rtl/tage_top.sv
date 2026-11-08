`timescale 1ns/1ps
module tage_top
  import tage_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,
  // predict
  input  logic [31:0] pc_i,
  output logic        pred_o,
  output tage_meta_t  meta_o,
  // update (one branch at a time, at resolve)
  input  logic        update_valid_i,
  input  logic [31:0] update_pc_i,
  input  logic        update_taken_i,
  input  tage_meta_t  update_meta_i
);

  // ---------------- hash (owns the GHR) ----------------
  logic [4*IDX_W-1:0] hash_idx;
  logic [4*TAG_W-1:0] hash_tag;

  tage_hash #(
    .IDX_W(IDX_W), .TAG_W(TAG_W),
    .HIST_LEN_1(HIST_LEN[0]), .HIST_LEN_2(HIST_LEN[1]),
    .HIST_LEN_3(HIST_LEN[2]), .HIST_LEN_4(HIST_LEN[3])
  ) u_hash (
    .clk(clk), .rst_n(rst_n), .pc(pc_i),
    .idx(hash_idx), .tag(hash_tag),
    .update_en(update_valid_i), .actual_taken(update_taken_i)
  );

  // ---------------- base table T0 (1K x 2-bit) ----------------
  // Reset value 2'b10 (weakly taken) to match tage_ref. Keep both the same!
  logic [(1<<BASE_IDX_W)-1:0][1:0] T0;   // packed (Verilator: NBA reset in loop)
  logic [1:0] t0_ctr_a, t0_ctr_b;
  assign t0_ctr_a = T0[pc_i[BASE_IDX_W+1:2]];
  assign t0_ctr_b = T0[update_pc_i[BASE_IDX_W+1:2]];

  logic                  t0_we;
  logic [BASE_IDX_W-1:0] t0_waddr;
  logic [1:0]            t0_wctr;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int k = 0; k < (1<<BASE_IDX_W); k++) T0[k] <= 2'b10;
    end else if (t0_we) begin
      T0[t0_waddr] <= t0_wctr;
    end
  end

  // ---------------- tagged tables T1..T4 ----------------
  logic [4:1]            a_valid, b_valid, a_u, b_u;
  logic [4:1][TAG_W-1:0] a_tag, b_tag;
  logic [4:1][CTR_W-1:0] a_ctr, b_ctr;

  logic [4:1]            t_we, t_wvalid, t_wu;
  logic [4:1][IDX_W-1:0] t_waddr;
  logic [4:1][TAG_W-1:0] t_wtag;
  logic [4:1][CTR_W-1:0] t_wctr;

  genvar g;
  generate
    for (g = 1; g <= 4; g++) begin : g_tab
      tage_table #(.IDX_W(IDX_W), .TAG_W(TAG_W), .CTR_W(CTR_W)) u_tab (
        .clk(clk), .rst_n(rst_n),
        .ra_idx  (hash_idx[(g-1)*IDX_W +: IDX_W]),
        .ra_valid(a_valid[g]), .ra_tag(a_tag[g]), .ra_ctr(a_ctr[g]), .ra_u(a_u[g]),
        .rb_idx  (update_meta_i.idx[g]),
        .rb_valid(b_valid[g]), .rb_tag(b_tag[g]), .rb_ctr(b_ctr[g]), .rb_u(b_u[g]),
        .we(t_we[g]), .w_idx(t_waddr[g]),
        .w_valid(t_wvalid[g]), .w_tag(t_wtag[g]), .w_ctr(t_wctr[g]), .w_u(t_wu[g])
      );
    end
  endgenerate

 
  logic [71:0] meta_flat;   // 3+3+32+32+1+1

  tage_predict #(.IDX_W(IDX_W), .TAG_W(TAG_W), .CTR_W(CTR_W)) u_predict (
    .t0_ctr_msb(t0_ctr_a[1]),
    .t_valid(a_valid), .t_tag(a_tag), .t_ctr(a_ctr), .t_u(a_u),
    .hash_idx(hash_idx), .hash_tag(hash_tag),
    .pred(pred_o), .meta(meta_flat)
  );

  assign meta_o = tage_meta_t'(meta_flat);   // same field order as the struct


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
