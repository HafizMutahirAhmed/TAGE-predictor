`timescale 1ns/1ps
module tage_ref
  import tage_pkg::*;
(
  input  logic             clk,
  input  logic             rst_n,
  // Prediction Interface
  input  logic [31:0]      pc_i,
  output logic             pred_o,
  output tage_meta_t       meta_o,
  // Update Interface
  input  logic             update_valid_i,
  input  logic [31:0]      update_pc_i,
  input  logic             update_taken_i,
  input  tage_meta_t       update_meta_i
);

  // Storage
  logic [1023:0][1:0]            T0;                   // Base bimodal table (1K x 2-bit)
  logic [4:1][255:0]             t_valid;
  logic [4:1][255:0][TAG_W-1:0]  t_tag;
  logic [4:1][255:0][CTR_W-1:0]  t_ctr;
  logic [4:1][255:0]             t_u;
  logic [31:0]      ghr;

  // Combinational Hash & Prediction Logic for pc_i
  always_comb begin
    logic [7:0] f [4:1];
    logic [7:0] computed_idx [4:1];
    logic [7:0] computed_tag [4:1];
    logic       hit [4:1];
    int         longest_hit;
    int         second_hit;
    logic [2:0] p_ctr;
    logic       b_pred;
    logic       a_pred;

    // 1. Hash computation for tables 1..4
    for (int i = 1; i <= 4; i++) begin
      f[i] = xor_fold(ghr, HIST_LEN[i-1]);
      computed_idx[i] = pc_i[9:2] ^ f[i];
      computed_tag[i] = pc_i[17:10] ^ rotl(f[i], 1);
      meta_o.idx[i]   = computed_idx[i];
      meta_o.tag[i]   = computed_tag[i];
      
      hit[i] = t_valid[i][computed_idx[i]] && (t_tag[i][computed_idx[i]] == computed_tag[i]);
    end

    // 2. Longest match selection
    longest_hit = 0;
    second_hit  = 0;
    for (int i = 4; i >= 1; i--) begin
      if (hit[i]) begin
        if (longest_hit == 0) longest_hit = i;
        else if (second_hit == 0) begin second_hit = i; break; end
      end
    end

    meta_o.prov = longest_hit[2:0];
    meta_o.alt  = second_hit[2:0];

    // 3. Base table prediction
    b_pred = T0[pc_i[11:2]][1]; // MSB of 2-bit counter

    // 4. Alternate prediction & Final prediction
    if (longest_hit == 0) begin
      pred_o         = b_pred;
      meta_o.pred    = b_pred;
      meta_o.alt_pred= b_pred;
    end else begin
      p_ctr = t_ctr[longest_hit][computed_idx[longest_hit]];
      pred_o = p_ctr[CTR_W-1]; // MSB of 3-bit counter
      meta_o.pred = pred_o;

      if (second_hit != 0) begin
        // If second hit exists, use its counter MSB
        automatic logic [2:0] alt_ctr = t_ctr[second_hit][computed_idx[second_hit]];
        a_pred = alt_ctr[CTR_W-1];
      end else begin
        a_pred = b_pred;
      end
      meta_o.alt_pred = a_pred;
    end
  end

  // Synchronous Update Logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ghr <= '0;
      for (int i = 0; i < 1024; i++) T0[i] <= 2'b10; // Default weakly taken
      for (int i = 1; i <= 4; i++) begin
        for (int j = 0; j < 256; j++) begin
          t_valid[i][j] <= 1'b0;
          t_tag[i][j]   <= '0;
          t_ctr[i][j]   <= 3'b011;
          t_u[i][j]     <= 1'b0;
        end
      end
    end else if (update_valid_i) begin
      automatic logic [2:0] prov = update_meta_i.prov;
      automatic logic [2:0] alt  = update_meta_i.alt;
      automatic logic       pred = update_meta_i.pred;
      automatic logic       alt_pred = update_meta_i.alt_pred;
      automatic logic [7:0] u_idx = update_meta_i.idx[prov];
      automatic logic [7:0] u_tag = update_meta_i.tag[prov];

      // 1. Update Provider or Base Counter
      if (prov != 0) begin
        if (update_taken_i) begin
          if (t_ctr[prov][u_idx] < 3'b111) t_ctr[prov][u_idx] <= t_ctr[prov][u_idx] + 1;
        end else begin
          if (t_ctr[prov][u_idx] > 3'b000) t_ctr[prov][u_idx] <= t_ctr[prov][u_idx] - 1;
        end
      end else begin
        automatic logic [9:0] b_idx = update_pc_i[11:2];
        if (update_taken_i) begin
          if (T0[b_idx] < 2'b11) T0[b_idx] <= T0[b_idx] + 1;
        end else begin
          if (T0[b_idx] > 2'b00) T0[b_idx] <= T0[b_idx] - 1;
        end
      end

      // 2. Useful bit (u) update rule
      if (prov != 0) begin
        if (pred != alt_pred) begin
          if (pred == update_taken_i) begin
            t_u[prov][u_idx] <= 1'b1;
          end
        end
      end

      // 3. Allocation rule on misprediction
      if (pred != update_taken_i && prov < 4) begin
        automatic int allocated = 0;
        for (int i = prov + 1; i <= 4; i++) begin
          automatic logic [7:0] alt_idx = update_meta_i.idx[i];
          if (!t_u[i][alt_idx]) begin
            t_valid[i][alt_idx] <= 1'b1;
            t_tag[i][alt_idx]   <= update_meta_i.tag[i];
            t_ctr[i][alt_idx]   <= update_taken_i ? 3'b100 : 3'b011;
            t_u[i][alt_idx]     <= 1'b0;
            allocated = 1;
            break;
          end
        end
        // If none free in longer tables, clear u bits in all longer tables
        if (!allocated) begin
          for (int i = prov + 1; i <= 4; i++) begin
            automatic logic [7:0] alt_idx = update_meta_i.idx[i];
            t_u[i][alt_idx] <= 1'b0;
          end
        end
      end

      // 4. Shift taken into GHR
      ghr <= {ghr[30:0], update_taken_i};
    end
  end

endmodule
