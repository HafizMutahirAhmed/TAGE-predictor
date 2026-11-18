// -----------------------------------------------------------------------------
// tage_table.v  (Member 1)
// Parameterized predictor table, 2^IDX_W entries of {valid, tag, ctr, u}.
//   * two combinational read ports: ra_* (predict, hashed idx) and
//     rb_* (update, saved meta idx -> read-modify-write in tage_update)
//   * one synchronous write port (we / w_idx / w_*)
// Base table T0: TAG_W=0, CTR_W=2. Then valid reads as 1, tag as 0, u as 0
// (the tag/valid/u inputs are ignored); the tag ports are 1 bit wide and unused.
//
// CEP optimization: the entries are stored in distributed RAM (LUTRAM)
// instead of flip-flops. LUTRAM cannot be reset, so after reset a small
// clear FSM writes the reset value into one entry per clock
// (2^IDX_W clocks). While it runs, `ready` is 0 and the write port is used
// by the FSM; the user must not predict or update until `ready` is 1.
// Reset values: valid=0, tag=0, ctr=CTR_INIT, u=0.
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
  output wire                                 ready,      // 0 while the clear FSM runs after reset

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

  // ---------------------------------------------------------------- clear FSM
  // After reset: clearing = 1 and clr_idx counts 0 .. DEPTH-1, one entry per
  // clock. After the last entry clearing = 0 and the table is ready.
  reg             clearing;
  reg [IDX_W-1:0] clr_idx;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      clearing <= 1'b1;
      clr_idx  <= {IDX_W{1'b0}};
    end else if (clearing) begin
      clr_idx <= clr_idx + 1'b1;
      if (&clr_idx) clearing <= 1'b0;          // just cleared the last entry
    end
  end

  assign ready = ~clearing;

  // ---------------------------------------------------------------- write port
  // While clearing, the FSM owns the write port and writes the reset values.
  wire             m_we;
  wire [IDX_W-1:0] m_idx;
  wire             m_valid, m_u;
  wire [TW-1:0]    m_tag;
  wire [CTR_W-1:0] m_ctr;

  assign m_we    = clearing | we;
  assign m_idx   = clearing ? clr_idx      : w_idx;
  assign m_valid = clearing ? 1'b0         : w_valid;
  assign m_tag   = clearing ? {TW{1'b0}}   : w_tag;
  assign m_ctr   = clearing ? CTR_INIT     : w_ctr;
  assign m_u     = clearing ? 1'b0         : w_u;

  // ---------------------------------------------------------------- counters
  (* ram_style = "distributed" *) reg [CTR_W-1:0] ctr_mem [0:DEPTH-1];

  always @(posedge clk) begin
    if (m_we) ctr_mem[m_idx] <= m_ctr;
  end

  assign ra_ctr = ctr_mem[ra_idx];
  assign rb_ctr = ctr_mem[rb_idx];

  // ---------------------------------------------------------------- valid / tag / u
  generate
    if (TAG_W > 0) begin : g_tagged
      (* ram_style = "distributed" *) reg          valid_mem [0:DEPTH-1];
      (* ram_style = "distributed" *) reg          u_mem     [0:DEPTH-1];
      (* ram_style = "distributed" *) reg [TW-1:0] tag_mem   [0:DEPTH-1];

      always @(posedge clk) begin
        if (m_we) begin
          valid_mem[m_idx] <= m_valid;
          u_mem[m_idx]     <= m_u;
          tag_mem[m_idx]   <= m_tag;
        end
      end

      assign ra_valid = valid_mem[ra_idx];
      assign ra_tag   = tag_mem[ra_idx];
      assign ra_u     = u_mem[ra_idx];
      assign rb_valid = valid_mem[rb_idx];
      assign rb_tag   = tag_mem[rb_idx];
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
