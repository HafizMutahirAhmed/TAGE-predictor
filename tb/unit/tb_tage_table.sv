`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// tb_tage_table.sv  (simulation only)
// Purpose : Unit test of tage_table in tagged (256 x {v,tag8,ctr3,u}) and
//           untagged base (TAG_W=0, CTR_W=2, 1024 x 2b) form.
//           Reset state, then random writes against a shadow array; checks both
//           combinational read ports, that a write lands only at the clock
//           edge, the constant valid/tag/u of the base form, and async reset.
// Ports   : none
// -----------------------------------------------------------------------------
module tb_tage_table;

  logic clk = 1'b0;
  always #5 clk = ~clk;

  int errors = 0;
  logic rst_n;

  // tagged table
  logic       t_we, t_wv, t_wu, t_arv, t_aru, t_brv, t_bru;
  logic [7:0] t_aa, t_ba, t_wa, t_wt, t_art, t_brt;
  logic [2:0] t_wc, t_arc, t_brc;

  tage_table #(.IDX_W(8), .TAG_W(8), .CTR_W(3)) u_t (
    .clk (clk), .rst_n (rst_n),
    .ra_idx (t_aa), .ra_valid (t_arv), .ra_tag (t_art), .ra_ctr (t_arc), .ra_u (t_aru),
    .rb_idx (t_ba), .rb_valid (t_brv), .rb_tag (t_brt), .rb_ctr (t_brc), .rb_u (t_bru),
    .we (t_we), .w_idx (t_wa), .w_valid (t_wv), .w_tag (t_wt), .w_ctr (t_wc), .w_u (t_wu)
  );

  // base table
  logic       b_we, b_arv, b_aru, b_brv, b_bru, b_art, b_brt;
  logic [9:0] b_aa, b_ba, b_wa;
  logic [1:0] b_wc, b_arc, b_brc;

  tage_table #(.IDX_W(10), .TAG_W(0), .CTR_W(2)) u_b (
    .clk (clk), .rst_n (rst_n),
    .ra_idx (b_aa), .ra_valid (b_arv), .ra_tag (b_art), .ra_ctr (b_arc), .ra_u (b_aru),
    .rb_idx (b_ba), .rb_valid (b_brv), .rb_tag (b_brt), .rb_ctr (b_brc), .rb_u (b_bru),
    .we (b_we), .w_idx (b_wa), .w_valid (1'b0), .w_tag (1'b1), .w_ctr (b_wc), .w_u (1'b1)
  );

  logic [12:0] t_shadow [256];
  logic [1:0]  b_shadow [1024];

  task automatic check_t(input string what, input logic [7:0] a, input logic v,
                         input logic [7:0] tg, input logic [2:0] c, input logic u);
    if ({v, tg, c, u} !== t_shadow[a]) begin
      $display("ERROR tagged %s addr %0d: got %b expected %b", what, a, {v, tg, c, u}, t_shadow[a]);
      errors++;
    end
  endtask

  task automatic reset_shadow();
    for (int i = 0; i < 256; i++)  t_shadow[i] = {1'b0, 8'h00, 3'b011, 1'b0};
    for (int i = 0; i < 1024; i++) b_shadow[i] = 2'b01;
  endtask

  task automatic check_all(input string what);
    for (int i = 0; i < 1024; i++) begin
      t_aa = 8'(i); t_ba = 8'(255 - i); b_aa = 10'(i); b_ba = 10'(1023 - i);
      #1;
      check_t({what, " A"}, t_aa, t_arv, t_art, t_arc, t_aru);
      check_t({what, " B"}, t_ba, t_brv, t_brt, t_brc, t_bru);
      if (b_arc !== b_shadow[b_aa] || b_brc !== b_shadow[b_ba]) begin
        $display("ERROR base %s addr %0d: %b expected %b", what, b_aa, b_arc, b_shadow[b_aa]);
        errors++;
      end
    end
  endtask

  initial begin
    t_we = 0; b_we = 0; t_aa = 0; t_ba = 0; t_wa = 0; b_aa = 0; b_ba = 0; b_wa = 0;
    t_wv = 0; t_wt = 0; t_wc = 0; t_wu = 0; b_wc = 0;
    rst_n = 0;
    @(negedge clk); rst_n = 1;

    // reset state
    reset_shadow();
    check_all("reset");

    for (int n = 0; n < 5000; n++) begin
      @(negedge clk);
      t_we = 1'($urandom_range(0, 1));
      t_wa = 8'($urandom);
      t_aa = (n % 3 == 0) ? t_wa : 8'($urandom);
      t_ba = (n % 3 == 1) ? t_wa : 8'($urandom);
      {t_wv, t_wt, t_wc, t_wu} = 13'($urandom);
      b_we = 1'($urandom_range(0, 1));
      b_wa = 10'($urandom);
      b_aa = (n % 3 == 0) ? b_wa : 10'($urandom);
      b_ba = (n % 3 == 1) ? b_wa : 10'($urandom);
      b_wc = 2'($urandom);
      #1;
      // before the edge both ports show the old contents
      check_t("portA", t_aa, t_arv, t_art, t_arc, t_aru);
      check_t("portB", t_ba, t_brv, t_brt, t_brc, t_bru);
      if (b_arc !== b_shadow[b_aa] || b_brc !== b_shadow[b_ba]) begin
        $display("ERROR base read: A %b/%b B %b/%b", b_arc, b_shadow[b_aa], b_brc, b_shadow[b_ba]);
        errors++;
      end
      if (b_arv !== 1'b1 || b_brv !== 1'b1 || b_aru !== 1'b0 || b_bru !== 1'b0 ||
          b_art !== 1'b0 || b_brt !== 1'b0) begin
        $display("ERROR base constant fields");
        errors++;
      end
      @(posedge clk);
      if (t_we) t_shadow[t_wa] = {t_wv, t_wt, t_wc, t_wu};
      if (b_we) b_shadow[b_wa] = b_wc;
      #1;
      // after the edge both ports see the new value
      check_t("portA-after", t_aa, t_arv, t_art, t_arc, t_aru);
      check_t("portB-after", t_ba, t_brv, t_brt, t_brc, t_bru);
      if (b_arc !== b_shadow[b_aa] || b_brc !== b_shadow[b_ba]) begin
        $display("ERROR base read after write"); errors++;
      end
    end

    // async reset (mid-cycle) restores the power-on state
    @(negedge clk); t_we = 0; b_we = 0;
    #2 rst_n = 0;
    #1 rst_n = 1;
    reset_shadow();
    check_all("async reset");

    if (errors == 0) $display("TEST PASSED: tb_tage_table");
    else             $fatal(1, "TEST FAILED: tb_tage_table %0d errors", errors);
    $finish;
  end

endmodule
