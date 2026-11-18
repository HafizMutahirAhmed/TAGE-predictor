// -----------------------------------------------------------------------------
// tb_tage.v  (team integration testbench)
// Drives tage_top (RTL) and tage_ref (behavioral) with the same traces, one
// branch at a time, 2 cycles per branch:
//   cycle A : pc_i = branch pc, compare RTL pred + meta vs tage_ref, save meta
//   cycle B : update_valid = 1 with the saved meta (each model gets its own),
//             pc_i = random garbage (predict port must not affect the update)
// After each trace every entry of T0..T4 and the GHR are compared.
// First mismatch -> FATAL + $stop. Prints TAGE mispredicts per trace.
// Last 4 traces: the hand-written patterns of rtl/board/branch_trace.mem,
// played exactly like the board does for SW[1:0] = 00..11 (40000 branches).
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
`include "tage_defines.vh"

module tb_tage;

  localparam N_BR = 20000;   // branches per trace

  reg clk = 1'b0;
  always #5 clk = ~clk;
  reg rst_n;

  reg  [31:0] pc, upd_pc;
  reg         upd_en, upd_taken;

  wire                    r_pred, m_pred;
  wire [`TAGE_META_W-1:0] r_meta, m_meta;
  reg  [`TAGE_META_W-1:0] r_umeta, m_umeta;

  wire ready;

  tage_top dut (
    .clk(clk), .rst_n(rst_n), .ready_o(ready),
    .pc_i(pc), .pred_o(r_pred), .meta_o(r_meta),
    .update_valid_i(upd_en), .update_pc_i(upd_pc),
    .update_taken_i(upd_taken), .update_meta_i(r_umeta)
  );

  tage_ref u_ref (
    .clk(clk), .rst_n(rst_n),
    .pc_i(pc), .pred_o(m_pred), .meta_o(m_meta),
    .update_valid_i(upd_en), .update_pc_i(upd_pc),
    .update_taken_i(upd_taken), .update_meta_i(m_umeta)
  );


  // ---------------------------------------------------------------- stats
  integer      n_br, mis_tage;
  integer      prov_cnt [0:4];
  integer      tot_tage, tot_br;
  reg [8*12:1] trace_name;           // right-aligned, NUL padded

  // ---------------------------------------------------------------- strings
  // number of characters in a NUL-padded string
  function integer str_len;
    input [8*12:1] s;
    integer b;
    begin
      str_len = 0;
      for (b = 0; b < 12; b = b + 1)
        if (s[8*b +: 8] != 8'h00) str_len = b + 1;
    end
  endfunction

  // left-justify in 12 characters, padded with spaces (like "%-12s")
  function [8*12:1] pad12;
    input [8*12:1] s;
    integer n;
    begin
      n     = str_len(s);
      pad12 = s << (8 * (12 - n));
      pad12 = pad12 | ({12{8'h20}} >> (8 * n));
    end
  endfunction

  // ---------------------------------------------------------------- LFSR
  reg [31:0] lfsr;
  function [31:0] lfsr_next;
    input [31:0] x;
    lfsr_next = {x[30:0], x[31] ^ x[21] ^ x[1] ^ x[0]};
  endfunction

  reg     rnd_b;
  reg     [31:0] rnd_w;
  integer ri;
  task rnd_bit;                      // rnd_b = next random bit
    begin
      lfsr  = lfsr_next(lfsr);
      rnd_b = lfsr[0];
    end
  endtask
  task rnd32;                        // rnd_w = 32 new random bits
    begin
      for (ri = 0; ri < 32; ri = ri + 1) rnd_bit;
      rnd_w = lfsr;
    end
  endtask

  // ---------------------------------------------------------------- fatal
  task fatal;
    input [8*48:1] msg;
    begin
      $display("FATAL: %0s", msg);
      $stop;
    end
  endtask

  // ---------------------------------------------------------------- reset
  integer rn;
  task do_reset;
    begin
      upd_en = 1'b0; upd_pc = 32'd0; upd_taken = 1'b0; pc = 32'd0;
      r_umeta = {`TAGE_META_W{1'b0}}; m_umeta = {`TAGE_META_W{1'b0}};
      @(negedge clk) rst_n = 1'b0;
      #1;
      if (ready !== 1'b0) fatal("ready_o not low during reset");
      @(negedge clk) rst_n = 1'b1;
      // the RTL tables are cleared one entry per clock (1024 clocks for T0)
      for (rn = 0; ready !== 1'b1; rn = rn + 1) begin
        if (rn > 2000) fatal("ready_o never went high");
        @(negedge clk);
      end
    end
  endtask

  // ---------------------------------------------------------------- one branch
  task branch;
    input [31:0] bpc;
    input        taken;
    begin
      // cycle A: predict
      @(negedge clk);
      upd_en = 1'b0;
      pc     = bpc;
      #1;
      if (^{r_pred, r_meta} === 1'bx) begin
        $display("[%0s #%0d] X on predictor outputs pc=%h", trace_name, n_br, bpc);
        fatal("X on predictor outputs");
      end
      if (r_pred !== m_pred || r_meta !== m_meta) begin
        $display("MISMATCH [%0s branch %0d] pc=%h taken=%b", trace_name, n_br, bpc, taken);
        $display("  RTL: pred=%b prov=%0d alt=%0d pred=%b alt_pred=%b idx=%h tag=%h",
                 r_pred, r_meta[`META_PROV], r_meta[`META_ALT], r_meta[`META_PRED],
                 r_meta[`META_ALT_PRED], r_meta[`META_IDX], r_meta[`META_TAG]);
        $display("  REF: pred=%b prov=%0d alt=%0d pred=%b alt_pred=%b idx=%h tag=%h",
                 m_pred, m_meta[`META_PROV], m_meta[`META_ALT], m_meta[`META_PRED],
                 m_meta[`META_ALT_PRED], m_meta[`META_IDX], m_meta[`META_TAG]);
        fatal("RTL vs reference mismatch");
      end
      if (r_pred != taken) mis_tage = mis_tage + 1;
      prov_cnt[r_meta[`META_PROV]] = prov_cnt[r_meta[`META_PROV]] + 1;
      r_umeta = r_meta;
      m_umeta = m_meta;
      // cycle B: update
      @(negedge clk);
      rnd32;
      pc        = rnd_w;     // garbage on the predict port
      upd_en    = 1'b1;
      upd_pc    = bpc;
      upd_taken = taken;
      @(posedge clk);
      n_br = n_br + 1;
    end
  endtask

  // ---------------------------------------------------------------- state compare
  // RTL tables are LUTRAM arrays (entry j = mem[j]); reference tables are
  // flat vectors: table G entry j at index (G-1)*256 + j, T0 entry j at [j*2 +: 2]
  integer state_err;
  integer j;
  `define CMP_TAB(G) \
    for (j = 0; j < 256; j = j + 1) begin \
      if (dut.g_tab[G].u_tab.g_tagged.valid_mem[j]   !== u_ref.t_valid[(G-1)*256+j] || \
          dut.g_tab[G].u_tab.g_tagged.u_mem[j]       !== u_ref.t_u[(G-1)*256+j]     || \
          dut.g_tab[G].u_tab.ctr_mem[j] !== u_ref.t_ctr[((G-1)*256+j)*3 +: 3]   || \
          (u_ref.t_valid[(G-1)*256+j] && dut.g_tab[G].u_tab.g_tagged.tag_mem[j] !== u_ref.t_tag[((G-1)*256+j)*8 +: 8])) begin \
        if (state_err < 5) $display("STATE MISMATCH T%0d[%0d]: rtl v=%b t=%h c=%b u=%b ref v=%b t=%h c=%b u=%b", G, j, \
          dut.g_tab[G].u_tab.g_tagged.valid_mem[j], dut.g_tab[G].u_tab.g_tagged.tag_mem[j], \
          dut.g_tab[G].u_tab.ctr_mem[j], dut.g_tab[G].u_tab.g_tagged.u_mem[j], \
          u_ref.t_valid[(G-1)*256+j], u_ref.t_tag[((G-1)*256+j)*8 +: 8], u_ref.t_ctr[((G-1)*256+j)*3 +: 3], u_ref.t_u[(G-1)*256+j]); \
        state_err = state_err + 1; \
      end \
    end

  task check_state;
    begin
      @(negedge clk); upd_en = 1'b0;
      state_err = 0;
      for (j = 0; j < 1024; j = j + 1)
        if (dut.u_t0.ctr_mem[j] !== u_ref.T0[j*2 +: 2]) begin
          if (state_err < 5) $display("STATE MISMATCH T0[%0d]: rtl %b ref %b", j, dut.u_t0.ctr_mem[j], u_ref.T0[j*2 +: 2]);
          state_err = state_err + 1;
        end
      `CMP_TAB(1)
      `CMP_TAB(2)
      `CMP_TAB(3)
      `CMP_TAB(4)
      if (dut.u_hash.ghr !== u_ref.ghr) begin
        $display("STATE MISMATCH GHR: rtl %h ref %h", dut.u_hash.ghr, u_ref.ghr);
        state_err = state_err + 1;
      end
      if (state_err != 0) begin
        $display("[%0s] %0d table/GHR entries differ", trace_name, state_err);
        fatal("table/GHR state differs");
      end
    end
  endtask

  // ---------------------------------------------------------------- trace wrapper
  integer pi;
  task start_trace;
    input [8*12:1] name;
    begin
      trace_name = name;
      n_br = 0; mis_tage = 0;
      for (pi = 0; pi <= 4; pi = pi + 1) prov_cnt[pi] = 0;
      lfsr = 32'hACE1_2345 ^ str_len(name);
      do_reset;
    end
  endtask

  task end_trace;
    begin
      check_state;
      $display("%s %7d | %7d (%5.2f%%) | prov %0d/%0d/%0d/%0d/%0d",
               pad12(trace_name), n_br, mis_tage, 100.0 * mis_tage / n_br,
               prov_cnt[0], prov_cnt[1], prov_cnt[2], prov_cnt[3], prov_cnt[4]);
      tot_br = tot_br + n_br; tot_tage = tot_tage + mis_tage;
    end
  endtask

  // ---------------------------------------------------------------- traces
  integer o, i, k, fi;
  reg     a;

  // nested loops: inner trip 7, outer trip 13
  task tr_loops;
    begin
      start_trace("loops");
      while (n_br < N_BR) begin
        for (o = 0; o < 13 && n_br < N_BR; o = o + 1) begin
          for (i = 0; i < 7 && n_br < N_BR; i = i + 1)
            branch(32'h0000_1040, i != 6);
          branch(32'h0000_1080, o != 12);
        end
      end
      end_trace;
    end
  endtask

  // alternating T/NT on one branch, plus a period-3 branch
  task tr_alternating;
    begin
      start_trace("alternating");
      for (k = 0; n_br < N_BR; k = k + 1) begin
        branch(32'h0000_2000, k[0]);
        branch(32'h0000_2010, (k % 3) == 0);
      end
      end_trace;
    end
  endtask

  // correlated at distance D (16..32 branches): branch B repeats branch A's
  // outcome after D-1 filler branches whose outcomes are fixed per position
  task tr_correlated;
    input integer  D;
    input [8*12:1] name;             // "corr_d<D>"
    begin
      start_trace(name);
      while (n_br < N_BR) begin
        rnd_bit; a = rnd_b;
        branch(32'h0000_3000, a);
        for (fi = 0; fi < D - 2; fi = fi + 1) branch(32'h0000_3100 + 4 * fi, fi[1]);
        branch(32'h0000_3800, a);
      end
      end_trace;
    end
  endtask

  // LFSR-random outcomes on 16 PCs (unpredictable)
  reg [31:0] bpc_r;
  reg        tk;
  task tr_random;
    begin
      start_trace("lfsr_random");
      while (n_br < N_BR) begin
        // same LFSR order as the SV version: outcome bit first, then the pc
        rnd_bit; tk    = rnd_b;
        rnd32;   bpc_r = 32'h0000_4000 + 4 * (rnd_w % 16);
        branch(bpc_r, tk);
      end
      end_trace;
    end
  endtask

  // a "program" of 512 random PCs, each biased (85%) in its own direction;
  // exercises aliasing, allocation pressure and u-clearing
  reg [31:0] pcs  [0:511];
  reg        bias [0:511];
  task tr_program;
    begin
      start_trace("program512");
      for (i = 0; i < 512; i = i + 1) begin
        rnd32;   pcs[i]  = rnd_w & 32'h000F_FFFC;
        rnd_bit; bias[i] = rnd_b;
      end
      while (n_br < N_BR) begin
        rnd32; k  = rnd_w % 512;
        rnd32; tk = (rnd_w % 100 < 85) ? bias[k] : !bias[k];
        branch(pcs[k], tk);
      end
      end_trace;
    end
  endtask

  // board patterns: the same branch_trace.mem the board plays
  localparam ROOM = 32, BOARD_RUN = 40000;
  reg [32:0] prog_rom [0:4*ROOM-1];

  function integer pat_len;          // same as trace_rom.v
    input integer sw;
    case (sw)
      0:       pat_len = 28;
      1:       pat_len = 2;
      2:       pat_len = 20;
      default: pat_len = 31;
    endcase
  endfunction

  function [8*12:1] prog_name;
    input integer sw;
    case (sw)
      0:       prog_name = "brd_loop";
      1:       prog_name = "brd_altern";
      2:       prog_name = "brd_corr";
      default: prog_name = "brd_mixed";
    endcase
  endfunction

  integer fd;
  task load_programs;
    begin
      fd = $fopen("rtl/board/branch_trace.mem", "r");
      if (fd != 0) begin
        $fclose(fd);
        $readmemh("rtl/board/branch_trace.mem", prog_rom);
      end else begin
        fd = $fopen("../../rtl/board/branch_trace.mem", "r");
        if (fd != 0) begin
          $fclose(fd);
          $readmemh("../../rtl/board/branch_trace.mem", prog_rom);
        end else begin
          fatal("rtl/board/branch_trace.mem not found");
        end
      end
    end
  endtask

  reg [32:0] line;
  reg [1:0]  sw2;
  reg [15:0] mis16, nbr16;
  task tr_real;
    input integer sw;
    begin
      start_trace(prog_name(sw));
      for (i = 0; i < BOARD_RUN; i = i + 1) begin
        line = prog_rom[sw * ROOM + i % pat_len(sw)];
        branch(line[31:0], line[32]);
      end
      end_trace;
      sw2 = sw; mis16 = mis_tage; nbr16 = n_br;
      $display("             board SW=%b shows: %h %h", sw2, mis16, nbr16);
    end
  endtask

  // ---------------------------------------------------------------- main
  integer sw;
  initial begin
    rst_n = 1'b1;
    tot_br = 0; tot_tage = 0;
    $display("TAGE storage = %0d bits",
             (1 << `TAGE_BASE_IDX_W) * 2 +
             `TAGE_NUM_T * (1 << `TAGE_IDX_W) * (1 + `TAGE_TAG_W + `TAGE_CTR_W + 1));
    $display("trace        branch |  TAGE mispred    | provider T0/T1/T2/T3/T4");
    tr_loops;
    tr_alternating;
    tr_correlated(16, "corr_d16");
    tr_correlated(24, "corr_d24");
    tr_correlated(32, "corr_d32");
    tr_random;
    tr_program;
    load_programs;
    for (sw = 0; sw < 4; sw = sw + 1) tr_real(sw);
    $display("%s %7d | %7d (%5.2f%%)", pad12("TOTAL"), tot_br,
             tot_tage, 100.0 * tot_tage / tot_br);
    $display("RTL matched tage_ref on every branch and every table entry.");
    $display("TEST PASSED");
    $finish;
  end

endmodule
