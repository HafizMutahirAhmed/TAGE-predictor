`timescale 1ns/1ps
module tage_update
  import tage_pkg::*;
(
  input  logic                      update_valid,
  input  logic [31:0]               update_pc,
  input  logic                      taken,
  input  tage_meta_t                meta,

  // current entry contents at meta.idx[i]  (index 1..4 = T1..T4)
  input  logic [4:1]                rd_valid,
  input  logic [4:1][TAG_W-1:0]     rd_tag,
  input  logic [4:1][CTR_W-1:0]     rd_ctr,
  input  logic [4:1]                rd_u,
  input  logic [1:0]                t0_ctr,        // base ctr at update_pc[11:2]

  // write port for base table T0
  output logic                      t0_we,
  output logic [BASE_IDX_W-1:0]     t0_waddr,
  output logic [1:0]                t0_wctr,

  // write ports for T1..T4
  output logic [4:1]                t_we,
  output logic [4:1][IDX_W-1:0]     t_waddr,
  output logic [4:1]                t_wvalid,
  output logic [4:1][TAG_W-1:0]     t_wtag,
  output logic [4:1][CTR_W-1:0]     t_wctr,
  output logic [4:1]                t_wu
);

  int  prov;
  logic found;

  always_comb begin
    prov = int'(meta.prov);

    // ---- defaults: no write; if a write happens it keeps the old fields ----
    t0_we    = 1'b0;
    t0_waddr = update_pc[BASE_IDX_W+1:2];
    t0_wctr  = t0_ctr;
    for (int i = 1; i <= 4; i++) begin
      t_we[i]     = 1'b0;
      t_waddr[i]  = meta.idx[i];
      t_wvalid[i] = rd_valid[i];
      t_wtag[i]   = rd_tag[i];
      t_wctr[i]   = rd_ctr[i];
      t_wu[i]     = rd_u[i];
    end
    found = 1'b0;

    if (update_valid) begin
      // ---------- 1. counter update ----------
      if (prov != 0) begin
        t_we[prov] = 1'b1;
        if (taken) begin
          if (rd_ctr[prov] != {CTR_W{1'b1}}) t_wctr[prov] = rd_ctr[prov] + 1'b1;
        end else begin
          if (rd_ctr[prov] != {CTR_W{1'b0}}) t_wctr[prov] = rd_ctr[prov] - 1'b1;
        end
        // ---------- 2. useful bit ----------
        if (meta.pred == taken && meta.alt_pred != taken)
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
      if (meta.pred != taken && prov < 4) begin
        for (int i = 1; i <= 4; i++) begin
          if (i > prov && !found && !rd_u[i]) begin
            found       = 1'b1;
            t_we[i]     = 1'b1;
            t_wvalid[i] = 1'b1;
            t_wtag[i]   = meta.tag[i];
            t_wctr[i]   = taken ? 3'b100 : 3'b011;
            t_wu[i]     = 1'b0;
          end
        end
        if (!found) begin
          for (int i = 1; i <= 4; i++) begin
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
