`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// tb_tage_hash.v  (simulation only)
// Purpose : Unit test of xor_fold / rotl (tage_funcs.vh) and tage_hash.
//   * xor_fold: hand-computed vectors for each history length and random
//     vectors against an independent chunk-based model.
//   * tage_hash: GHR reset to 0, shift with newest outcome in bit 0, hold
//     when upd_en = 0, and idx/tag for random pc against the spec formula.
// Ports   : none
// -----------------------------------------------------------------------------
`include "tage_defines.vh"

module tb_tage_hash;

  `include "tage_funcs.vh"

  localparam NUM_T = `TAGE_NUM_T;
  localparam IDX_W = `TAGE_IDX_W;
  localparam TAG_W = `TAGE_TAG_W;

  reg clk = 1'b0;
  always #5 clk = ~clk;

  integer errors = 0;

  localparam GHR_W = 32;
  reg                    rst, upd_en, upd_taken;
  reg  [31:0]            pc;
  wire [NUM_T*IDX_W-1:0] idx;          // table i at [(i-1)*IDX_W +: IDX_W]
  wire [NUM_T*TAG_W-1:0] tag;
  wire [GHR_W-1:0]       ghr;

  tage_hash dut (
    .clk (clk), .rst_n (!rst), .pc (pc), .update_en (upd_en), .actual_taken (upd_taken),
    .idx (idx), .tag (tag)
  );
  assign ghr = dut.ghr;

  function integer hist_len;
    input integer i;
    case (i)
      1:       hist_len = `TAGE_HIST_LEN_1;
      2:       hist_len = `TAGE_HIST_LEN_2;
      3:       hist_len = `TAGE_HIST_LEN_3;
      default: hist_len = `TAGE_HIST_LEN_4;
    endcase
  endfunction

  // independent model: XOR 8-bit chunks, zero-pad the last one
  function [7:0] fold_ref;
    input [31:0]  h;
    input integer len;
    reg   [31:0]  m, hm;
    begin
      m        = (len >= 32) ? 32'hFFFF_FFFF : ((32'h1 << len) - 1);
      hm       = h & m;
      fold_ref = hm[7:0] ^ hm[15:8] ^ hm[23:16] ^ hm[31:24];
    end
  endfunction

  reg [7:0] got;
  task expect_fold;
    input [31:0]  h;
    input integer len;
    input [7:0]   exp;
    begin
      got = xor_fold(h, len);
      if (got !== exp) begin
        $display("ERROR xor_fold(%h,%0d) = %h expected %h", h, len, got, exp);
        errors = errors + 1;
      end
    end
  endtask

  reg [31:0] model_ghr;
  reg [31:0] h;
  reg [7:0]  v, e, f, ei, et, ef;
  integer    hl;
  integer    n, i, s;

  initial begin
    // ---- xor_fold directed
    expect_fold(32'hFFFF_FFFF, 4,  8'h0F);   // zero-padded half chunk
    expect_fold(32'h0000_00A5, 8,  8'hA5);
    expect_fold(32'h0000_3CA5, 16, 8'h99);   // A5 ^ 3C
    expect_fold(32'h1234_5678, 32, 8'h08);   // 78^56^34^12
    expect_fold(32'hDEAD_BEEF, 4,  8'h0F);
    expect_fold(32'hDEAD_BEEF, 16, 8'h51);   // EF ^ BE
    // ---- xor_fold random
    for (n = 0; n < 2000; n = n + 1) begin
      h = $random;
      for (i = 1; i <= NUM_T; i = i + 1) begin
        hl = hist_len(i);          // temporaries: one function call per statement
        ef = fold_ref(h, hl);
        expect_fold(h, hl, ef);
      end
    end

    // ---- rotl
    for (n = 0; n < 256; n = n + 1)
      for (s = 0; s < 8; s = s + 1) begin
        v = n;
        e = (v << s) | (v >> (8 - s));
        if (rotl(v, s) !== e) begin
          $display("ERROR rotl(%h,%0d) = %h expected %h", v, s, rotl(v, s), e);
          errors = errors + 1;
        end
      end

    // ---- tage_hash
    rst = 1; upd_en = 0; upd_taken = 0; pc = 32'd0;
    @(negedge clk); @(negedge clk);
    rst = 0;
    if (ghr !== 32'd0) begin $display("ERROR ghr not 0 after reset"); errors = errors + 1; end
    model_ghr = 0;

    for (n = 0; n < 5000; n = n + 1) begin
      @(negedge clk);
      pc        = $random;
      upd_en    = ({$random} % 4) != 0;
      upd_taken = $random;
      #1;
      if (ghr !== model_ghr) begin $display("ERROR ghr %h expected %h", ghr, model_ghr); errors = errors + 1; end
      for (i = 1; i <= NUM_T; i = i + 1) begin
        f  = fold_ref(model_ghr, hist_len(i));
        ei = pc[9:2] ^ f;
        et = pc[17:10] ^ {f[6:0], f[7]};
        if (idx[(i-1)*IDX_W +: IDX_W] !== ei || tag[(i-1)*TAG_W +: TAG_W] !== et) begin
          $display("ERROR T%0d pc=%h ghr=%h idx/tag %h/%h expected %h/%h",
                   i, pc, model_ghr, idx[(i-1)*IDX_W +: IDX_W], tag[(i-1)*TAG_W +: TAG_W], ei, et);
          errors = errors + 1;
        end
      end
      @(posedge clk);
      if (upd_en) model_ghr = {model_ghr[30:0], upd_taken};
    end

    // newest outcome lands in bit 0
    @(negedge clk); upd_en = 1; upd_taken = 1;
    @(negedge clk); upd_en = 0;
    if (ghr[0] !== 1'b1) begin $display("ERROR newest outcome not in bit 0"); errors = errors + 1; end
    @(negedge clk); rst = 1;
    @(negedge clk); rst = 0;
    if (ghr !== 32'd0) begin $display("ERROR ghr not cleared by reset"); errors = errors + 1; end

    if (errors == 0) $display("TEST PASSED: tb_tage_hash");
    else begin
      $display("FATAL: TEST FAILED: tb_tage_hash %0d errors", errors);
      $stop;
    end
    $finish;
  end

endmodule
