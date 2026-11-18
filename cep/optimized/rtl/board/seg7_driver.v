`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// seg7_driver.v
// Purpose : 8-digit multiplexed hex display driver for the Nexys A7 (common
//           anode, active-low segments and anodes). Digit d shows
//           value[4d+3:4d]; digit 0 is the rightmost (AN[0]). Each digit is on
//           for DIGIT_CYCLES clocks: 12500 @ 100 MHz -> 1 ms per full refresh
//           (1 kHz). Outputs are registered.
// Params  : DIGIT_CYCLES  clocks per digit
// Ports   : clk, rst      clock, synchronous reset (all digits off)
//           value         32-bit value to display
//           seg_n[6:0]    {CG,CF,CE,CD,CC,CB,CA}, active low
//           dp_n          decimal point, active low (kept off)
//           an_n[7:0]     digit anodes, active low
// -----------------------------------------------------------------------------
module seg7_driver #(
  parameter DIGIT_CYCLES = 12500
) (
  input  wire        clk,
  input  wire        rst,
  input  wire [31:0] value,
  output reg  [6:0]  seg_n,
  output reg         dp_n,
  output reg  [7:0]  an_n
);

  // ceil(log2(x)) as a constant function (Verilog-2001 has no $clog2)
  function integer clog2;
    input integer x;
    integer v;
    begin
      v     = x - 1;
      clog2 = 0;
      while (v > 0) begin
        clog2 = clog2 + 1;
        v     = v >> 1;
      end
    end
  endfunction

  localparam DW = clog2(DIGIT_CYCLES + 1);
  localparam [DW-1:0] DIV_LAST = DIGIT_CYCLES - 1;

  reg  [DW-1:0] div;
  reg  [2:0]    digit;
  wire [3:0]    nib;
  reg  [6:0]    seg;

  always @(posedge clk) begin
    if (rst) begin
      div   <= {DW{1'b0}};
      digit <= 3'd0;
    end else if (div == DIV_LAST) begin
      div   <= {DW{1'b0}};
      digit <= digit + 3'd1;
    end else begin
      div <= div + 1'b1;
    end
  end

  assign nib = value[{digit, 2'b00} +: 4];

  // segment order {g,f,e,d,c,b,a}, active high
  always @* begin
    case (nib)
      4'h0: seg = 7'h3F;
      4'h1: seg = 7'h06;
      4'h2: seg = 7'h5B;
      4'h3: seg = 7'h4F;
      4'h4: seg = 7'h66;
      4'h5: seg = 7'h6D;
      4'h6: seg = 7'h7D;
      4'h7: seg = 7'h07;
      4'h8: seg = 7'h7F;
      4'h9: seg = 7'h6F;
      4'hA: seg = 7'h77;
      4'hB: seg = 7'h7C;
      4'hC: seg = 7'h39;
      4'hD: seg = 7'h5E;
      4'hE: seg = 7'h79;
      default: seg = 7'h71;
    endcase
  end

  always @(posedge clk) begin
    if (rst) begin
      an_n  <= 8'hFF;
      seg_n <= 7'h7F;
      dp_n  <= 1'b1;
    end else begin
      an_n  <= ~(8'b1 << digit);
      seg_n <= ~seg;
      dp_n  <= 1'b1;
    end
  end

endmodule
