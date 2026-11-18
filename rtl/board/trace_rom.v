`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// trace_rom.v
// Purpose : Feeds test branches to the predictor on the board. The branches
//           are hand-written in branch_trace.mem (one line = {taken, pc}) and
//           loaded into a small ROM with $readmemh.
//           The file holds 4 patterns (room for 32 branches each, the real
//           length is PAT_LEN); `mode` (SW[1:0]) picks the pattern and it is
//           played over and over:
//             00 loop   01 alternating   10 correlated if/else   11 mixed
//           The current branch is presented on pc/taken; `adv` moves to the
//           next one at the clock edge (after the last line it wraps to the
//           first).
//           Note: pattern lengths 28/2/20/31 are on purpose not 8, 16 or 32:
//           the hash folds the history 8 bits at a time, so a pattern that
//           repeats every 8/16/32 branches gives the same folded history at
//           different places and TAGE cannot tell them apart. The ROM is read synchronously, so pc/taken are valid in
//           the cycle after reset and in the cycle after every `adv`.
// Params  : MEM_FILE  trace file (added to the Vivado project as a source)
//           LEN_W     log2(room per pattern)
// Ports   : clk, rst        clock, synchronous active-high reset (restarts at 0)
//           mode            pattern select (keep stable during a run)
//           adv             advance to the next branch
//           valid           high once out of reset
//           pc, taken       current branch
// -----------------------------------------------------------------------------
module trace_rom #(
  parameter MEM_FILE = "branch_trace.mem",
  parameter LEN_W    = 5                  // room for 32 branches per pattern
) (
  input  wire        clk,
  input  wire        rst,
  input  wire [1:0]  mode,
  input  wire        adv,
  output reg         valid,
  output wire [31:0] pc,
  output wire        taken
);

  // number of lines in each pattern of branch_trace.mem (SW = 00, 01, 10, 11)
  function [LEN_W:0] pat_len;
    input [1:0] m;
    begin
      case (m)
        2'd0:    pat_len = 28;
        2'd1:    pat_len = 2;
        2'd2:    pat_len = 20;
        default: pat_len = 31;
      endcase
    end
  endfunction

  reg [32:0] rom [0:(4 << LEN_W)-1];   // {taken, pc}
  initial $readmemh(MEM_FILE, rom);

  reg [LEN_W-1:0] pos, pos_next;       // line inside the pattern
  reg [32:0]      q;

  always @* begin
    if (rst)                                     pos_next = {LEN_W{1'b0}};
    else if (!adv)                               pos_next = pos;
    else if ({1'b0, pos} == pat_len(mode) - 1'b1) pos_next = {LEN_W{1'b0}};   // wrap
    else                                         pos_next = pos + 1'b1;
  end

  always @(posedge clk) begin
    if (rst) begin
      pos   <= {LEN_W{1'b0}};
      valid <= 1'b0;
    end else begin
      pos   <= pos_next;
      valid <= 1'b1;
    end
  end

  always @(posedge clk) q <= rom[{mode, pos_next}];

  assign {taken, pc} = q;

endmodule
