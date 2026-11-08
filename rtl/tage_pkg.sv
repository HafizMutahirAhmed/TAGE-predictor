`timescale 1ns/1ps
package tage_pkg;
  parameter int NUM_T        = 4;     // Number of tagged tables (T1..T4)
  parameter int HIST_LEN[4]  = '{4, 8, 16, 32}; // History lengths for T1..T4
  parameter int IDX_W        = 8;     // Tagged table index width (256 entries = 8 bits)
  parameter int TAG_W        = 8;     // Tag width
  parameter int CTR_W        = 3;     // Tagged table counter width
  parameter int BASE_IDX_W   = 10;    // Base table index width (1K entries = 10 bits)

  // Meta bundle packed struct
  typedef struct packed {
    logic [2:0]       prov;
    logic [2:0]       alt;
    logic [4:1][7:0]  idx;
    logic [4:1][7:0]  tag;
    logic             pred;
    logic             alt_pred;
  } tage_meta_t;

  // Helper function: XOR fold
  function automatic [7:0] xor_fold(input logic [31:0] data, input int length);
    logic [7:0] folded;
    folded = '0;
    for (int i = 0; i < length; i++) begin
      folded[i % 8] ^= data[i];
    end
    return folded;
  endfunction

  // Helper function: Rotate left (8-bit)
  // (shift must be 0..7; a variable part-select is not legal, so use shifts)
  function automatic [7:0] rotl(input logic [7:0] val, input int shift);
    logic [15:0] dbl;
    dbl = {val, val} << (shift % 8);
    return dbl[15:8];
  endfunction
endpackage
