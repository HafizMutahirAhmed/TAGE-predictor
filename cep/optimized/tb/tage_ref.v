// -----------------------------------------------------------------------------
// tage_ref.v - independent behavioural reference model of the TAGE predictor
// (arrays + loops, no shared code with rtl/ except the parameter header).
// meta_o / update_meta_i: flat 72-bit meta bundle, layout in tage_defines.vh.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "tage_defines.vh"

module tage_ref (
  input  wire                     clk,
  input  wire                     rst_n,
  // Prediction Interface
  input  wire [31:0]              pc_i,
  output reg                      pred_o,
  output reg  [`TAGE_META_W-1:0]  meta_o,
  // Update Interface
  input  wire                     update_valid_i,
  input  wire [31:0]              update_pc_i,
  input  wire                     update_taken_i,
  input  wire [`TAGE_META_W-1:0]  update_meta_i
);

  `include "tage_funcs.vh"

  localparam TAG_W = `TAGE_TAG_W;
  localparam CTR_W = `TAGE_CTR_W;

  // Storage: flat vectors (like the packed arrays of the SV version, so the
  // reset can be a single non-blocking assignment). Entry j of table i:
  localparam N = 256;
  reg [2*1024-1:0]      T0;              // Base bimodal table (1K x 2-bit)
  reg [4*N-1:0]         t_valid;
  reg [4*N*TAG_W-1:0]   t_tag;
  reg [4*N*CTR_W-1:0]   t_ctr;
  reg [4*N-1:0]         t_u;
  reg [31:0]            ghr;

  `define REF_T0(j)     T0[(j)*2 +: 2]
  `define REF_V(i, j)   t_valid[((i)-1)*N + (j)]
  `define REF_T(i, j)   t_tag[(((i)-1)*N + (j))*TAG_W +: TAG_W]
  `define REF_C(i, j)   t_ctr[(((i)-1)*N + (j))*CTR_W +: CTR_W]
  `define REF_U(i, j)   t_u[((i)-1)*N + (j)]

  // hist length of table i (1..4)
  function integer hist_len;
    input integer i;
    begin
      case (i)
        1:       hist_len = `TAGE_HIST_LEN_1;
        2:       hist_len = `TAGE_HIST_LEN_2;
        3:       hist_len = `TAGE_HIST_LEN_3;
        default: hist_len = `TAGE_HIST_LEN_4;
      endcase
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Combinational Hash & Prediction Logic for pc_i
  // ---------------------------------------------------------------------------
  reg [7:0]   f            [1:4];
  reg [7:0]   computed_idx [1:4];
  reg [7:0]   computed_tag [1:4];
  reg         hit          [1:4];
  integer     longest_hit;
  integer     second_hit;
  reg [2:0]   p_ctr;
  reg [2:0]   alt_ctr;
  reg         b_pred;
  reg         a_pred;
  integer     i;

  always @* begin
    meta_o = {`TAGE_META_W{1'b0}};

    // 1. Hash computation for tables 1..4
    for (i = 1; i <= 4; i = i + 1) begin
      f[i]            = xor_fold(ghr, hist_len(i));
      computed_idx[i] = pc_i[9:2] ^ f[i];
      computed_tag[i] = pc_i[17:10] ^ rotl(f[i], 1);
      meta_o[`META_IDX_T(i)] = computed_idx[i];
      meta_o[`META_TAG_T(i)] = computed_tag[i];

      hit[i] = `REF_V(i, computed_idx[i]) && (`REF_T(i, computed_idx[i]) == computed_tag[i]);
    end

    // 2. Longest match selection
    longest_hit = 0;
    second_hit  = 0;
    for (i = 4; i >= 1; i = i - 1) begin
      if (hit[i]) begin
        if (longest_hit == 0)     longest_hit = i;
        else if (second_hit == 0) second_hit  = i;
      end
    end

    meta_o[`META_PROV] = longest_hit[2:0];
    meta_o[`META_ALT]  = second_hit[2:0];

    // 3. Base table prediction
    b_pred = T0[pc_i[11:2]*2 + 1]; // MSB of 2-bit counter

    // 4. Alternate prediction & Final prediction
    if (longest_hit == 0) begin
      pred_o                  = b_pred;
      meta_o[`META_PRED]      = b_pred;
      meta_o[`META_ALT_PRED]  = b_pred;
    end else begin
      p_ctr  = `REF_C(longest_hit, computed_idx[longest_hit]);
      pred_o = p_ctr[CTR_W-1]; // MSB of 3-bit counter
      meta_o[`META_PRED] = pred_o;

      if (second_hit != 0) begin
        // If second hit exists, use its counter MSB
        alt_ctr = `REF_C(second_hit, computed_idx[second_hit]);
        a_pred  = alt_ctr[CTR_W-1];
      end else begin
        a_pred = b_pred;
      end
      meta_o[`META_ALT_PRED] = a_pred;
    end
  end

  // ---------------------------------------------------------------------------
  // Synchronous Update Logic
  // ---------------------------------------------------------------------------
  reg [2:0] prov, alt;
  reg       pred, alt_pred;
  reg [7:0] u_idx, u_tag, alt_idx;
  reg [9:0] b_idx;
  integer   allocated;
  integer   k;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ghr     <= 32'd0;
      T0      <= {1024{2'b10}};             // Default weakly taken
      t_valid <= {(4*N){1'b0}};
      t_tag   <= {(4*N*TAG_W){1'b0}};
      t_ctr   <= {(4*N){3'b011}};
      t_u     <= {(4*N){1'b0}};
    end else if (update_valid_i) begin
      prov     = update_meta_i[`META_PROV];
      alt      = update_meta_i[`META_ALT];
      pred     = update_meta_i[`META_PRED];
      alt_pred = update_meta_i[`META_ALT_PRED];
      u_idx    = (prov != 0) ? update_meta_i[`META_IDX_T(prov)] : 8'd0;
      u_tag    = (prov != 0) ? update_meta_i[`META_TAG_T(prov)] : 8'd0;

      // 1. Update Provider or Base Counter
      if (prov != 0) begin
        if (update_taken_i) begin
          if (`REF_C(prov, u_idx) < 3'b111) `REF_C(prov, u_idx) <= `REF_C(prov, u_idx) + 1;
        end else begin
          if (`REF_C(prov, u_idx) > 3'b000) `REF_C(prov, u_idx) <= `REF_C(prov, u_idx) - 1;
        end
      end else begin
        b_idx = update_pc_i[11:2];
        if (update_taken_i) begin
          if (`REF_T0(b_idx) < 2'b11) `REF_T0(b_idx) <= `REF_T0(b_idx) + 1;
        end else begin
          if (`REF_T0(b_idx) > 2'b00) `REF_T0(b_idx) <= `REF_T0(b_idx) - 1;
        end
      end

      // 2. Useful bit (u) update rule
      if (prov != 0) begin
        if (pred != alt_pred) begin
          if (pred == update_taken_i) begin
            `REF_U(prov, u_idx) <= 1'b1;
          end
        end
      end

      // 3. Allocation rule on misprediction
      if (pred != update_taken_i && prov < 4) begin
        allocated = 0;
        for (k = prov + 1; k <= 4; k = k + 1) begin
          alt_idx = update_meta_i[`META_IDX_T(k)];
          if (!allocated && !`REF_U(k, alt_idx)) begin
            `REF_V(k, alt_idx) <= 1'b1;
            `REF_T(k, alt_idx) <= update_meta_i[`META_TAG_T(k)];
            `REF_C(k, alt_idx) <= update_taken_i ? 3'b100 : 3'b011;
            `REF_U(k, alt_idx) <= 1'b0;
            allocated = 1;
          end
        end
        // If none free in longer tables, clear u bits in all longer tables
        if (!allocated) begin
          for (k = prov + 1; k <= 4; k = k + 1) begin
            alt_idx = update_meta_i[`META_IDX_T(k)];
            `REF_U(k, alt_idx) <= 1'b0;
          end
        end
      end

      // 4. Shift taken into GHR
      ghr <= {ghr[30:0], update_taken_i};
    end
  end

endmodule
