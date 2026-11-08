// Holds the 32-bit global history register (GHR) and computes, for each tagged
// table t = 1..4:
//
//     f      = xor_fold(ghr[HIST_LEN_t-1:0], 8)
//     idx[t] = pc[9:2]   ^ f
//     tag[t] = pc[17:10] ^ rotl(f, 1)
//
// GHR convention: the newest outcome enters at bit 0, so ghr[L-1:0] is always
// the L most recent branches.
//
// Flat output buses: table t occupies bits [(t-1)*W +: W], i.e.
//     idx = {idx4, idx3, idx2, idx1}      tag = {tag4, tag3, tag2, tag1}

`timescale 1ns/1ps

module tage_hash #(
    parameter IDX_W      = 8,
    parameter TAG_W      = 8,
    parameter HIST_LEN_1 = 4,
    parameter HIST_LEN_2 = 8,
    parameter HIST_LEN_3 = 16,
    parameter HIST_LEN_4 = 32
) (
    input  wire               clk,
    input  wire               rst_n,

    // Predict side
    input  wire [31:0]        pc,
    output wire [4*IDX_W-1:0] idx,
    output wire [4*TAG_W-1:0] tag,

    // Update side: shift the resolved outcome into the GHR
    input  wire               update_en,
    input  wire               actual_taken
);

    localparam GHR_W      = 32;
    localparam FOLD_W     = 8;                    // spec: fold to 8 bits
    localparam PC_IDX_LSB = 2;                    // pc[9:2]
    localparam PC_TAG_LSB = PC_IDX_LSB + IDX_W;   // pc[17:10]

    // -------------------------------------------------------------------------
    // Global history register
    // -------------------------------------------------------------------------
    reg [GHR_W-1:0] ghr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ghr <= {GHR_W{1'b0}};
        else if (update_en)
            ghr <= {ghr[GHR_W-2:0], actual_taken};
    end

    // -------------------------------------------------------------------------
    // XOR-fold the len newest history bits into FOLD_W bits.
    // The loop bound is a constant (GHR_W) so synthesis always unrolls it;
    // len is a constant at every call site, so the "if" folds away and each
    // table ends up with its own fixed XOR tree.
    // -------------------------------------------------------------------------
    function [FOLD_W-1:0] xor_fold(input [GHR_W-1:0] h, input integer len);
        integer b;
        begin
            xor_fold = {FOLD_W{1'b0}};
            for (b = 0; b < GHR_W; b = b + 1)
                if (b < len)
                    xor_fold[b % FOLD_W] = xor_fold[b % FOLD_W] ^ h[b];
        end
    endfunction

    // -------------------------------------------------------------------------
    // Per-table hash
    // -------------------------------------------------------------------------
    wire [FOLD_W-1:0] fold1 = xor_fold(ghr, HIST_LEN_1);
    wire [FOLD_W-1:0] fold2 = xor_fold(ghr, HIST_LEN_2);
    wire [FOLD_W-1:0] fold3 = xor_fold(ghr, HIST_LEN_3);
    wire [FOLD_W-1:0] fold4 = xor_fold(ghr, HIST_LEN_4);

    wire [IDX_W-1:0] pc_idx = pc[PC_IDX_LSB +: IDX_W];
    wire [TAG_W-1:0] pc_tag = pc[PC_TAG_LSB +: TAG_W];

    // rotl by 1:  {f[6:0], f[7]}
    assign idx = { pc_idx ^ fold4,
                   pc_idx ^ fold3,
                   pc_idx ^ fold2,
                   pc_idx ^ fold1 };

    assign tag = { pc_tag ^ {fold4[FOLD_W-2:0], fold4[FOLD_W-1]},
                   pc_tag ^ {fold3[FOLD_W-2:0], fold3[FOLD_W-1]},
                   pc_tag ^ {fold2[FOLD_W-2:0], fold2[FOLD_W-1]},
                   pc_tag ^ {fold1[FOLD_W-2:0], fold1[FOLD_W-1]} };

    // -------------------------------------------------------------------------
    // Simulation-only check (ignored by synthesis)
    // -------------------------------------------------------------------------
    // synthesis translate_off
    initial begin
        if (IDX_W != FOLD_W || TAG_W != FOLD_W)
            $display("ERROR tage_hash: spec requires IDX_W = TAG_W = 8 (got %0d / %0d)",
                     IDX_W, TAG_W);
        if (HIST_LEN_1 < 1 || HIST_LEN_2 < 1 || HIST_LEN_3 < 1 || HIST_LEN_4 < 1 ||
            HIST_LEN_1 > GHR_W || HIST_LEN_2 > GHR_W ||
            HIST_LEN_3 > GHR_W || HIST_LEN_4 > GHR_W)
            $display("ERROR tage_hash: every HIST_LEN must be in 1..%0d", GHR_W);
    end
    // synthesis translate_on

endmodule
