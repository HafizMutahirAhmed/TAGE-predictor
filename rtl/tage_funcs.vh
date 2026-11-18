// -----------------------------------------------------------------------------
// tage_funcs.vh
// Helper functions of the old tage_pkg. Include it INSIDE a module body:
//     module m; `include "tage_funcs.vh" ... endmodule
// -----------------------------------------------------------------------------

// XOR fold: fold the `length` newest history bits into 8 bits
function [7:0] xor_fold;
  input [31:0] data;
  input integer length;
  integer i;
  begin
    xor_fold = 8'h00;
    for (i = 0; i < length; i = i + 1)
      xor_fold[i % 8] = xor_fold[i % 8] ^ data[i];
  end
endfunction

// Rotate left (8-bit)
// (shift must be 0..7; a variable part-select is not legal, so use shifts)
function [7:0] rotl;
  input [7:0]   val;
  input integer shift;
  reg   [15:0]  dbl;
  begin
    dbl  = {val, val} << (shift % 8);
    rotl = dbl[15:8];
  end
endfunction
