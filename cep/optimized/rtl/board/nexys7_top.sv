`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// nexys7_top.sv
// Purpose : Nexys A7-100T demo: runs the TAGE predictor on hand-written test
//           branches (trace_rom, loaded from branch_trace.mem) and shows the mispredict count and the branch count on the
//           7-segment display.
//           Press BTNC: latch SW[1:0] as pattern select, re-initialise the
//           predictor, trace ROM and counters (every run starts from the power-on
//           state), then run RUN_LEN branches, 2 cycles per branch:
//             S_PRED: predict, register pred + meta (cycle A)
//             S_UPD : update both predictors, count, advance trace (cycle B)
// Params  : DIGIT_CYCLES, RUN_LEN (shrunk in simulation),
//           TRACE_FILE (branch trace for trace_rom)
// Ports   : CLK100MHZ    100 MHz board clock
//           CPU_RESETN   active-low reset button
//           BTNC         start run
//           SW[1:0]      pattern: 00 loop 01 alternating 10 correlated
//                        11 mixed   (SW[15:2] unused)
//           LED[0]       done            LED[1]  last TAGE prediction
//           LED[2]       last outcome    LED[3]  last branch mispredicted by TAGE
//           LED[5:4]     latched pattern    LED[6]  running
//           LED[7]       predictors initialising
//           LED[15:8]    progress bar (1/8 of RUN_LEN per LED)
//           CA..CG, DP   segments (active low); AN[7:0] digit anodes (active low)
//           7-seg: AN[7:4] = TAGE mispredicts (hex), AN[3:0] = branches run (hex)
// -----------------------------------------------------------------------------
module nexys7_top
  import tage_pkg::*;
#(
  parameter int DIGIT_CYCLES = 6250,     // 50 MHz core clock -> 1 kHz refresh
  parameter int RUN_LEN      = 40000,
  parameter     TRACE_FILE   = "branch_trace.mem"
) (
  input  logic        CLK100MHZ,
  input  logic        CPU_RESETN,
  input  logic        BTNC,
  /* verilator lint_off UNUSEDSIGNAL */
  input  logic [15:0] SW,
  /* verilator lint_on UNUSEDSIGNAL */
  output logic [15:0] LED,
  output logic        CA,
  output logic        CB,
  output logic        CC,
  output logic        CD,
  output logic        CE,
  output logic        CF,
  output logic        CG,
  output logic        DP,
  output logic [7:0]  AN
);

  // ---------------------------------------------------------------- clock
  // The TAGE predict path (hash -> table read -> tag compare -> provider
  // select) is ~11 ns, so the core runs at 50 MHz: MMCM 100 MHz x10 /20.
  logic clk, mmcm_locked;
`ifdef VERILATOR
  assign clk         = CLK100MHZ;   // simulation: no Xilinx primitives
  assign mmcm_locked = 1'b1;
`else
  logic clk_mmcm, clk_fb;
  MMCME2_BASE #(
    .CLKIN1_PERIOD    (10.0),
    .DIVCLK_DIVIDE    (1),
    .CLKFBOUT_MULT_F  (10.0),       // VCO = 1000 MHz
    .CLKOUT0_DIVIDE_F (20.0)        // 50 MHz
  ) u_mmcm (
    .CLKIN1 (CLK100MHZ), .CLKFBIN (clk_fb), .CLKFBOUT (clk_fb), .CLKFBOUTB (),
    .CLKOUT0 (clk_mmcm), .CLKOUT0B (), .CLKOUT1 (), .CLKOUT1B (), .CLKOUT2 (),
    .CLKOUT2B (), .CLKOUT3 (), .CLKOUT3B (), .CLKOUT4 (), .CLKOUT5 (), .CLKOUT6 (),
    .LOCKED (mmcm_locked), .PWRDWN (1'b0), .RST (1'b0)
  );
  BUFG u_bufg (.I (clk_mmcm), .O (clk));
`endif

  // hold everything in reset until the MMCM has locked (2-FF synchroniser)
  (* ASYNC_REG = "TRUE" *) logic [1:0] lock_sync = 2'b00;
  always_ff @(posedge clk or negedge mmcm_locked) begin
    if (!mmcm_locked) lock_sync <= 2'b00;
    else              lock_sync <= {lock_sync[0], 1'b1};
  end

  // ---------------------------------------------------------------- reset / inputs
  // Buttons and switches are not synchronised to clk, so each one first goes
  // through 2 flip-flops (synchroniser). No debouncer is needed: a run is
  // deterministic, BTNC is ignored while a run is going, and an extra press
  // from bounce only restarts the same run (same result); extra resets from
  // a bouncing CPU_RESETN are harmless.
  (* ASYNC_REG = "TRUE" *) logic [1:0] resetn_s = 2'b00;
  (* ASYNC_REG = "TRUE" *) logic [1:0] btnc_s   = 2'b00;
  (* ASYNC_REG = "TRUE" *) logic [1:0] sw_s1;
  (* ASYNC_REG = "TRUE" *) logic [1:0] sw_s2;
  always_ff @(posedge clk) begin
    resetn_s <= {resetn_s[0], CPU_RESETN};
    btnc_s   <= {btnc_s[0],   BTNC};
    sw_s1    <= SW[1:0];
    sw_s2    <= sw_s1;
  end

  logic rst;
  assign rst = ~resetn_s[1] | ~lock_sync[1];

  // start = one-cycle pulse when BTNC goes from 0 to 1
  logic btnc_q, start;
  always_ff @(posedge clk) begin
    if (rst) btnc_q <= 1'b0;
    else     btnc_q <= btnc_s[1];
  end
  assign start = btnc_s[1] & ~btnc_q;

  // ---------------------------------------------------------------- run control
  typedef enum logic [2:0] {S_IDLE, S_INIT, S_PRED, S_UPD, S_DONE} state_t;
  state_t     state;
  logic       soft_rst, core_rst, in_upd;
  logic [1:0] mode_q;

  assign core_rst = rst | soft_rst;
  // tage_top: after reset its tables are cleared one entry per clock
  // (1024 clocks for T0); S_INIT waits for ready_o (tage_ready)
  logic core_rst_n;
  assign core_rst_n = ~core_rst;
  assign in_upd   = (state == S_UPD);

  logic        tage_ready, tg_valid, tg_taken;
  logic [31:0] tg_pc;
  logic        tage_pred;
  tage_meta_t  tage_meta;

  // registered prediction (cycle A -> cycle B)
  logic        p_tage, p_taken;
  logic [31:0] p_pc;
  tage_meta_t  p_meta;

  logic [15:0] tage_cnt, br_cnt;
  logic        done;

  always_ff @(posedge clk) begin
    if (rst) begin
      state    <= S_IDLE;
      soft_rst <= 1'b0;
      mode_q   <= 2'd0;
      p_tage   <= 1'b0;
      p_taken  <= 1'b0;
      p_pc     <= '0;
      p_meta   <= '0;
    end else begin
      soft_rst <= 1'b0;
      case (state)
        S_IDLE, S_DONE: begin
          if (start) begin
            soft_rst <= 1'b1;
            mode_q   <= sw_s2;
            state    <= S_INIT;
          end
        end
        S_INIT: begin
          if (!soft_rst && tage_ready && tg_valid) state <= S_PRED;
        end
        S_PRED: begin
          if (done) begin
            state <= S_DONE;
          end else begin
            p_tage  <= tage_pred;
            p_meta  <= tage_meta;
            p_pc    <= tg_pc;
            p_taken <= tg_taken;
            state   <= S_UPD;
          end
        end
        S_UPD:   state <= S_PRED;
        default: state <= S_IDLE;
      endcase
    end
  end

  // ---------------------------------------------------------------- datapath
  trace_rom #(.MEM_FILE(TRACE_FILE)) u_tg (
    .clk   (clk),
    .rst   (core_rst),
    .mode  (mode_q),
    .adv   (in_upd),
    .valid (tg_valid),
    .pc    (tg_pc),
    .taken (tg_taken)
  );


  // dont_touch: the test patterns use only a few fixed PCs, so without it
  // Vivado would delete table entries those PCs can never reach and the
  // utilization report would not show the real cost of the predictor
  (* dont_touch = "true" *)
  tage_top u_tage (
    .clk            (clk),
    .rst_n          (core_rst_n),
    .ready_o        (tage_ready),
    .pc_i           (tg_pc),
    .pred_o         (tage_pred),
    .meta_o         (tage_meta),
    .update_valid_i (in_upd),
    .update_pc_i    (p_pc),
    .update_taken_i (p_taken),
    .update_meta_i  (p_meta)
  );


  perf_counters #(.RUN_LEN(RUN_LEN)) u_perf (
    .clk       (clk),
    .rst       (core_rst),
    .br_valid  (in_upd),
    .tage_miss (p_tage != p_taken),
    .tage_cnt  (tage_cnt),
    .br_cnt    (br_cnt),
    .done      (done)
  );

  // ---------------------------------------------------------------- LEDs
  logic led_pred, led_taken, led_miss;
  always_ff @(posedge clk) begin
    if (core_rst) begin
      led_pred  <= 1'b0;
      led_taken <= 1'b0;
      led_miss  <= 1'b0;
    end else if (in_upd) begin
      led_pred  <= p_tage;
      led_taken <= p_taken;
      led_miss  <= (p_tage != p_taken);
    end
  end

  logic [7:0] progress;
  always_comb begin
    for (int k = 0; k < 8; k++) progress[k] = (br_cnt >= 16'((RUN_LEN * (k + 1)) / 8));
  end

  always_ff @(posedge clk) begin
    LED <= {progress,
            ~tage_ready,
            (state == S_PRED) || (state == S_UPD),
            mode_q,
            led_miss, led_taken, led_pred, done};
  end

  // ---------------------------------------------------------------- 7-segment
  logic [6:0] seg_n;
  seg7_driver #(.DIGIT_CYCLES(DIGIT_CYCLES)) u_seg (
    .clk   (clk),
    .rst   (rst),
    .value ({tage_cnt, br_cnt}),
    .seg_n (seg_n),
    .dp_n  (DP),
    .an_n  (AN)
  );
  assign {CG, CF, CE, CD, CC, CB, CA} = seg_n;

endmodule
