`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// tb_tage_hash.sv  (simulation only)
// Purpose : Unit test of tage_pkg::xor_fold and tage_hash.
//   * xor_fold: hand-computed vectors for each history length and random
//     vectors against an independent chunk-based model.
//   * tage_hash: GHR reset to 0, shift with newest outcome in bit 0, hold
//     when upd_en = 0, and idx/tag for random pc against the spec formula.
// Ports   : none
// -----------------------------------------------------------------------------
module tb_tage_hash;
  import tage_pkg::*;

  logic clk = 1'b0;
  always #5 clk = ~clk;

  int errors = 0;

  localparam int GHR_W = 32;
  logic                      rst, upd_en, upd_taken;
  logic [31:0]               pc;
  logic [NUM_T:1][IDX_W-1:0] idx;
  logic [NUM_T:1][TAG_W-1:0] tag;
  logic [GHR_W-1:0]          ghr;

  tage_hash dut (
    .clk (clk), .rst_n (!rst), .pc (pc), .update_en (upd_en), .actual_taken (upd_taken),
    .idx (idx), .tag (tag)
  );
  assign ghr = dut.ghr;

  // independent model: XOR 8-bit chunks, zero-pad the last one
  function automatic bit [7:0] fold_ref(bit [31:0] h, int len);
    bit [31:0] m;
    m = (len >= 32) ? 32'hFFFF_FFFF : ((32'h1 << len) - 1);
    h = h & m;
    return h[7:0] ^ h[15:8] ^ h[23:16] ^ h[31:24];
  endfunction

  task automatic expect_fold(bit [31:0] h, int len, bit [7:0] exp);
    bit [7:0] got;
    got = xor_fold(h, len);
    if (got !== exp) begin
      $display("ERROR xor_fold(%08h,%0d) = %02h expected %02h", h, len, got, exp);
      errors++;
    end
  endtask

  bit [31:0] model_ghr;

  initial begin
    // ---- xor_fold directed
    expect_fold(32'hFFFF_FFFF, 4,  8'h0F);   // zero-padded half chunk
    expect_fold(32'h0000_00A5, 8,  8'hA5);
    expect_fold(32'h0000_3CA5, 16, 8'h99);   // A5 ^ 3C
    expect_fold(32'h1234_5678, 32, 8'h08);   // 78^56^34^12
    expect_fold(32'hDEAD_BEEF, 4,  8'h0F);
    expect_fold(32'hDEAD_BEEF, 16, 8'h51);   // EF ^ BE
    // ---- xor_fold random
    for (int n = 0; n < 2000; n++) begin
      bit [31:0] h;
      h = $urandom;
      for (int i = 1; i <= NUM_T; i++) expect_fold(h, int'(HIST_LEN[i-1]), fold_ref(h, int'(HIST_LEN[i-1])));
    end

    // ---- tage_pkg::rotl
    for (int n = 0; n < 256; n++)
      for (int s = 0; s < 8; s++) begin
        bit [7:0] v, e;
        v = 8'(n);
        e = 8'((v << s) | (v >> (8 - s)));
        if (rotl(v, s) !== e) begin
          $display("ERROR rotl(%02h,%0d) = %02h expected %02h", v, s, rotl(v, s), e);
          errors++;
        end
      end

    // ---- tage_hash
    rst = 1; upd_en = 0; upd_taken = 0; pc = '0;
    @(negedge clk); @(negedge clk);
    rst = 0;
    if (ghr !== '0) begin $display("ERROR ghr not 0 after reset"); errors++; end
    model_ghr = 0;

    for (int n = 0; n < 5000; n++) begin
      @(negedge clk);
      pc        = $urandom;
      upd_en    = 1'($urandom_range(0, 3) != 0);
      upd_taken = 1'($urandom);
      #1;
      if (ghr !== model_ghr) begin $display("ERROR ghr %08h expected %08h", ghr, model_ghr); errors++; end
      for (int i = 1; i <= NUM_T; i++) begin
        bit [7:0] f, ei, et;
        f  = fold_ref(model_ghr, int'(HIST_LEN[i-1]));
        ei = pc[9:2] ^ f;
        et = pc[17:10] ^ {f[6:0], f[7]};
        if (idx[i] !== ei || tag[i] !== et) begin
          $display("ERROR T%0d pc=%08h ghr=%08h idx/tag %02h/%02h expected %02h/%02h",
                   i, pc, model_ghr, idx[i], tag[i], ei, et);
          errors++;
        end
      end
      @(posedge clk);
      if (upd_en) model_ghr = {model_ghr[30:0], upd_taken};
    end

    // newest outcome lands in bit 0
    @(negedge clk); upd_en = 1; upd_taken = 1;
    @(negedge clk); upd_en = 0;
    if (ghr[0] !== 1'b1) begin $display("ERROR newest outcome not in bit 0"); errors++; end
    @(negedge clk); rst = 1;
    @(negedge clk); rst = 0;
    if (ghr !== '0) begin $display("ERROR ghr not cleared by reset"); errors++; end

    if (errors == 0) $display("TEST PASSED: tb_tage_hash");
    else             $fatal(1, "TEST FAILED: tb_tage_hash %0d errors", errors);
    $finish;
  end

endmodule
