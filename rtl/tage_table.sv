// -----------------------------------------------------------------------------
// tage_table.sv  (Member 1)
// Parameterized predictor table, 2^IDX_W entries of {valid, tag, ctr, u}.
//   * two combinational read ports: ra_* (predict, hashed idx) and
//     rb_* (update, saved meta idx -> read-modify-write in tage_update)
//   * one synchronous write port (we / w_idx / w_*)
//   * async active-low reset: valid=0, tag=0, ctr=CTR_INIT, u=0
// Base table T0: TAG_W=0, CTR_W=2. Then valid reads as 1, tag as 0, u as 0
// (the tag/valid/u inputs are ignored); the tag ports are 1 bit wide and unused.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module tage_table #(
  parameter int IDX_W = 8,
  parameter int TAG_W = 8,
  parameter int CTR_W = 3,
  // reset counter value: weakly not-taken (3'b011 / 2'b01) by default
  parameter logic [CTR_W-1:0] CTR_INIT = {1'b0, {(CTR_W-1){1'b1}}},
  localparam int TW = (TAG_W > 0) ? TAG_W : 1      // physical tag port width
) (
  input  logic             clk,
  input  logic             rst_n,

  // read port A (predict)
  input  logic [IDX_W-1:0] ra_idx,
  output logic             ra_valid,
  output logic [TW-1:0]    ra_tag,
  output logic [CTR_W-1:0] ra_ctr,
  output logic             ra_u,

  // read port B (update)
  input  logic [IDX_W-1:0] rb_idx,
  output logic             rb_valid,
  output logic [TW-1:0]    rb_tag,
  output logic [CTR_W-1:0] rb_ctr,
  output logic             rb_u,

  // write port
  input  logic             we,
  input  logic [IDX_W-1:0] w_idx,
  input  logic             w_valid,
  input  logic [TW-1:0]    w_tag,
  input  logic [CTR_W-1:0] w_ctr,
  input  logic             w_u
);

  localparam int DEPTH = 1 << IDX_W;

  logic [DEPTH-1:0][CTR_W-1:0] ctr_mem;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int k = 0; k < DEPTH; k++) ctr_mem[k] <= CTR_INIT;
    end else if (we) begin
      ctr_mem[w_idx] <= w_ctr;
    end
  end

  assign ra_ctr = ctr_mem[ra_idx];
  assign rb_ctr = ctr_mem[rb_idx];

  generate
    if (TAG_W > 0) begin : g_tagged
      logic [DEPTH-1:0]         valid_mem;
      logic [DEPTH-1:0]         u_mem;
      logic [DEPTH-1:0][TW-1:0] tag_mem;

      always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          for (int k = 0; k < DEPTH; k++) begin
            valid_mem[k] <= 1'b0;
            u_mem[k]     <= 1'b0;
            tag_mem[k]   <= '0;
          end
        end else if (we) begin
          valid_mem[w_idx] <= w_valid;
          u_mem[w_idx]     <= w_u;
          tag_mem[w_idx]   <= w_tag;
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
      assign ra_tag   = '0;
      assign ra_u     = 1'b0;
      assign rb_valid = 1'b1;
      assign rb_tag   = '0;
      assign rb_u     = 1'b0;
    end
  endgenerate

endmodule
