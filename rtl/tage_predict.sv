// Purely combinational. Compares tags, picks the provider (longest-history
// hit) and the alternate (second-longest hit), and produces the final
// prediction plus the metadata bundle saved for the update stage.
//
//   hit[t]   = valid[t] && (stored tag == hashed tag)
//   prov     = highest t with hit[t]           (0 = no hit  -> base table T0)
//   alt      = highest t < prov with hit[t]    (0 = none    -> base table T0)
//   pred     = MSB of provider ctr  (T0 ctr MSB when prov == 0)
//   alt_pred = MSB of alternate ctr (T0 ctr MSB when alt  == 0)
//
// Flat buses: table t occupies bits [(t-1)*W +: W].
//
// meta layout (META_W = 72 bits with default widths), MSB first:
//     meta = { prov[2:0], alt[2:0], idx[31:0], tag[31:0], pred, alt_pred }
//       prov     = meta[71:69]
//       alt      = meta[68:66]
//       idx      = meta[65:34]   (idx4 .. idx1)
//       tag      = meta[33:2]    (tag4 .. tag1)
//       pred     = meta[1]
//       alt_pred = meta[0]
// This matches the field order of tage_meta_t in the shared spec.
// =============================================================================
`timescale 1ns/1ps

module tage_predict #(
    parameter IDX_W  = 8,
    parameter TAG_W  = 8,
    parameter CTR_W  = 3,
    parameter META_W = 3 + 3 + 4*IDX_W + 4*TAG_W + 1 + 1
) (
    // Table read data
    input  wire               t0_ctr_msb,   // base table T0 prediction
    input  wire [4:1]         t_valid,      // T1..T4 valid bits
    input  wire [4*TAG_W-1:0] t_tag,        // T1..T4 stored tags
    input  wire [4*CTR_W-1:0] t_ctr,        // T1..T4 counters
    input  wire [4:1]         t_u,          // T1..T4 useful bits (used by tage_update, not here)

    // Hashed index/tag from tage_hash
    input  wire [4*IDX_W-1:0] hash_idx,
    input  wire [4*TAG_W-1:0] hash_tag,

    // Results
    output wire               pred,
    output wire [META_W-1:0]  meta
);

    // Highest set bit of v (1..4), or 0 when v is all zeros.
    function [2:0] highest_hit(input [4:1] v);
        casez (v)
            4'b1???: highest_hit = 3'd4;
            4'b01??: highest_hit = 3'd3;
            4'b001?: highest_hit = 3'd2;
            4'b0001: highest_hit = 3'd1;
            default: highest_hit = 3'd0;
        endcase
    endfunction

    reg  [4:1] hit;         // tag hit per tagged table
    reg  [4:1] hit_below;   // hits strictly below the provider
    reg  [4:0] dir;         // direction bit per table, dir[0] = base T0
    wire [2:0] prov;
    wire [2:0] alt;
    wire       alt_pred;

    // 1. Tag compare + direction bits
    integer t;
    always @* begin
        dir[0] = t0_ctr_msb;
        for (t = 1; t <= 4; t = t + 1) begin
            hit[t] = t_valid[t] &&
                     (t_tag[(t-1)*TAG_W +: TAG_W] == hash_tag[(t-1)*TAG_W +: TAG_W]);
            dir[t] = t_ctr[(t-1)*CTR_W + CTR_W - 1];
        end
    end

    // 2. Provider = longest hit; alternate = longest hit below the provider
    assign prov = highest_hit(hit);

    always @* begin
        hit_below = hit;
        if (prov != 3'd0)
            hit_below[prov] = 1'b0;
    end

    assign alt = highest_hit(hit_below);

    // 3. Prediction and metadata
    assign pred     = dir[prov];
    assign alt_pred = dir[alt];
    assign meta     = {prov, alt, hash_idx, hash_tag, pred, alt_pred};

endmodule
