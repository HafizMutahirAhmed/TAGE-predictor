// -----------------------------------------------------------------------------
// tage_update.v
// Purely combinational update rules 1-3: write data and write enables for
// T0..T4. Flat buses: table t occupies bits [(t-1)*W +: W].
// meta layout: see tage_defines.vh.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "tage_defines.vh"

module tage_update #(
  parameter IDX_W      = `TAGE_IDX_W,
  parameter TAG_W      = `TAGE_TAG_W,
  parameter CTR_W      = `TAGE_CTR_W,
  parameter BASE_IDX_W = `TAGE_BASE_IDX_W
) (
  input  wire                     update_valid,
  input  wire [31:0]              update_pc,
  input  wire                     taken,
  input  wire [`TAGE_META_W-1:0]  meta,

  // current entry contents at meta idx[i]  (index 1..4 = T1..T4)
  input  wire [4:1]               rd_valid,
  input  wire [4*TAG_W-1:0]       rd_tag,
  input  wire [4*CTR_W-1:0]       rd_ctr,
  input  wire [4:1]               rd_u,
  input  wire [1:0]               t0_ctr,        // base ctr at update_pc[11:2]

  // write port for base table T0
  output reg                      t0_we,
  output reg  [BASE_IDX_W-1:0]    t0_waddr,
  output reg  [1:0]               t0_wctr,

  // write ports for T1..T4
  output reg  [4:1]               t_we,
  output reg  [4*IDX_W-1:0]       t_waddr,
  output reg  [4:1]               t_wvalid,
  output reg  [4*TAG_W-1:0]       t_wtag,
  output reg  [4*CTR_W-1:0]       t_wctr,
  output reg  [4:1]               t_wu
);

  integer prov;
  integer i;
  reg     found;

  always @* begin
    prov = {29'd0, meta[`META_PROV]};

    // ---- defaults: no write; if a write happens it keeps the old fields ----
    t0_we    = 1'b0;
    t0_waddr = update_pc[BASE_IDX_W+1:2];
    t0_wctr  = t0_ctr;
    t_we     = 4'b0000;
    t_waddr  = meta[`META_IDX];
    t_wvalid = rd_valid;
    t_wtag   = rd_tag;
    t_wctr   = rd_ctr;
    t_wu     = rd_u;
    found    = 1'b0;

    if (update_valid) begin
      // ---------- 1. counter update ----------
      if (prov != 0) begin
        t_we[prov] = 1'b1;
        if (taken) begin
          if (rd_ctr[(prov-1)*CTR_W +: CTR_W] != {CTR_W{1'b1}})
            t_wctr[(prov-1)*CTR_W +: CTR_W] = rd_ctr[(prov-1)*CTR_W +: CTR_W] + 1'b1;
        end else begin
          if (rd_ctr[(prov-1)*CTR_W +: CTR_W] != {CTR_W{1'b0}})
            t_wctr[(prov-1)*CTR_W +: CTR_W] = rd_ctr[(prov-1)*CTR_W +: CTR_W] - 1'b1;
        end
        // ---------- 2. useful bit ----------
        if (meta[`META_PRED] == taken && meta[`META_ALT_PRED] != taken)
          t_wu[prov] = 1'b1;
      end else begin
        t0_we = 1'b1;
        if (taken) begin
          if (t0_ctr != 2'b11) t0_wctr = t0_ctr + 2'd1;
        end else begin
          if (t0_ctr != 2'b00) t0_wctr = t0_ctr - 2'd1;
        end
      end

      // ---------- 3. allocation on mispredict ----------
      if (meta[`META_PRED] != taken && prov < 4) begin
        for (i = 1; i <= 4; i = i + 1) begin
          if (i > prov && !found && !rd_u[i]) begin
            found                           = 1'b1;
            t_we[i]                         = 1'b1;
            t_wvalid[i]                     = 1'b1;
            t_wtag[(i-1)*TAG_W +: TAG_W]    = meta[`META_TAG_T(i)];
            t_wctr[(i-1)*CTR_W +: CTR_W]    = taken ? 3'b100 : 3'b011;
            t_wu[i]                         = 1'b0;
          end
        end
        if (!found) begin
          for (i = 1; i <= 4; i = i + 1) begin
            if (i > prov) begin
              t_we[i] = 1'b1;     // rewrite same entry, but u = 0
              t_wu[i] = 1'b0;
            end
          end
        end
      end
    end
  end

endmodule
