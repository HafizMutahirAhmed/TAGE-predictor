// -----------------------------------------------------------------------------
// tage_table.v  (Member 1)
// Parameterized predictor table, 2^IDX_W entries of {valid, tag, ctr, u}.
//   * two combinational read ports: ra_* (predict, hashed idx) and
//     rb_* (update, saved meta idx -> read-modify-write in tage_update)
//   * one synchronous write port (we / w_idx / w_*)
//   * async active-low reset: valid=0, tag=0, ctr=CTR_INIT, u=0
// Base table T0: TAG_W=0, CTR_W=2. Then valid reads as 1, tag as 0, u as 0
// (the tag/valid/u inputs are ignored); the tag ports are 1 bit wide and unused.
// Storage is kept in flat vectors (entry k of ctr_mem at [k*CTR_W +: CTR_W]),
// so every entry is a flip-flop with an async reset (Verilog has no packed
// 2-D arrays; an unpacked array cannot be reset in one assignment).
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module tage_table #(
  parameter IDX_W = 8,
  parameter TAG_W = 8,
  parameter CTR_W = 3,
  // reset counter value: weakly not-taken (3'b011 / 2'b01) by default
  parameter [CTR_W-1:0] CTR_INIT = {1'b0, {(CTR_W-1){1'b1}}}
) (
  input  wire                                 clk,
  input  wire                                 rst_n,

  // read port A (predict)
  input  wire [IDX_W-1:0]                     ra_idx,
  output wire                                 ra_valid,
  output wire [((TAG_W > 0) ? TAG_W : 1)-1:0] ra_tag,
  output wire [CTR_W-1:0]                     ra_ctr,
  output wire                                 ra_u,

  // read port B (update)
  input  wire [IDX_W-1:0]                     rb_idx,
  output wire                                 rb_valid,
  output wire [((TAG_W > 0) ? TAG_W : 1)-1:0] rb_tag,
  output wire [CTR_W-1:0]                     rb_ctr,
  output wire                                 rb_u,

  // write port
  input  wire                                 we,
  input  wire [IDX_W-1:0]                     w_idx,
  input  wire                                 w_valid,
  input  wire [((TAG_W > 0) ? TAG_W : 1)-1:0] w_tag,
  input  wire [CTR_W-1:0]                     w_ctr,
  input  wire                                 w_u
);

  localparam TW    = (TAG_W > 0) ? TAG_W : 1;      // physical tag port width
  localparam DEPTH = 1 << IDX_W;

  // One-hot write select (like the element write of a packed array in
  // SystemVerilog): entry e is written when wsel[e] = 1. Each entry is a
  // flip-flop group with its own async reset; reads are plain array muxes
  // through the *_rd wire views.
  wire [DEPTH-1:0] wsel = {{(DEPTH-1){1'b0}}, we} << w_idx;

  reg  [DEPTH*CTR_W-1:0] ctr_mem;
  wire [CTR_W-1:0]       ctr_rd [0:DEPTH-1];

  genvar e;
  generate
    for (e = 0; e < DEPTH; e = e + 1) begin : g_ctr
      always @(posedge clk or negedge rst_n) begin
        if (!rst_n)       ctr_mem[e*CTR_W +: CTR_W] <= CTR_INIT;
        else if (wsel[e]) ctr_mem[e*CTR_W +: CTR_W] <= w_ctr;
      end
      assign ctr_rd[e] = ctr_mem[e*CTR_W +: CTR_W];
    end
  endgenerate

  assign ra_ctr = ctr_rd[ra_idx];
  assign rb_ctr = ctr_rd[rb_idx];

  generate
    if (TAG_W > 0) begin : g_tagged
      reg  [DEPTH-1:0]    valid_mem;
      reg  [DEPTH-1:0]    u_mem;
      reg  [DEPTH*TW-1:0] tag_mem;
      wire [TW-1:0]       tag_rd [0:DEPTH-1];

      genvar te;
      for (te = 0; te < DEPTH; te = te + 1) begin : g_ent
        always @(posedge clk or negedge rst_n) begin
          if (!rst_n) begin
            valid_mem[te]         <= 1'b0;
            u_mem[te]             <= 1'b0;
            tag_mem[te*TW +: TW]  <= {TW{1'b0}};
          end else if (wsel[te]) begin
            valid_mem[te]         <= w_valid;
            u_mem[te]             <= w_u;
            tag_mem[te*TW +: TW]  <= w_tag;
          end
        end
        assign tag_rd[te] = tag_mem[te*TW +: TW];
      end

      assign ra_valid = valid_mem[ra_idx];
      assign ra_tag   = tag_rd[ra_idx];
      assign ra_u     = u_mem[ra_idx];
      assign rb_valid = valid_mem[rb_idx];
      assign rb_tag   = tag_rd[rb_idx];
      assign rb_u     = u_mem[rb_idx];
    end else begin : g_base
      // untagged base table: always "valid", no tag, no useful bit
      assign ra_valid = 1'b1;
      assign ra_tag   = {TW{1'b0}};
      assign ra_u     = 1'b0;
      assign rb_valid = 1'b1;
      assign rb_tag   = {TW{1'b0}};
      assign rb_u     = 1'b0;
    end
  endgenerate

endmodule
