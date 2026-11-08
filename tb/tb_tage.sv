// -----------------------------------------------------------------------------
// tb_tage.sv  (team integration testbench)
// Drives tage_top (RTL) and tage_ref (behavioral) with the same traces, one
// branch at a time, 2 cycles per branch:
//   cycle A : pc_i = branch pc, compare RTL pred + meta vs tage_ref, save meta
//   cycle B : update_valid = 1 with the saved meta (each model gets its own),
//             pc_i = random garbage (predict port must not affect the update)
// After each trace every entry of T0..T4 and the GHR are compared.
// First mismatch -> $fatal. Prints TAGE mispredicts per trace.
// Last 4 traces: the hand-written patterns of rtl/board/branch_trace.mem,
// played exactly like the board does for SW[1:0] = 00..11 (40000 branches).
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_tage;
  import tage_pkg::*;

  localparam int N_BR = 20000;   // branches per trace

  logic clk = 1'b0;
  always #5 clk = ~clk;
  logic rst_n;

  logic [31:0] pc, upd_pc;
  logic        upd_en, upd_taken;

  logic        r_pred, m_pred;
  tage_meta_t  r_meta, m_meta, r_umeta, m_umeta;

  tage_top dut (
    .clk(clk), .rst_n(rst_n),
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
  int n_br, mis_tage;
  int prov_cnt [0:4];
  int tot_tage, tot_br;
  string trace_name;

  // ---------------------------------------------------------------- LFSR
  logic [31:0] lfsr;
  function automatic logic [31:0] lfsr_next(logic [31:0] x);
    return {x[30:0], x[31] ^ x[21] ^ x[1] ^ x[0]};
  endfunction
  function automatic logic rnd_bit();
    lfsr = lfsr_next(lfsr);
    return lfsr[0];
  endfunction
  function automatic logic [31:0] rnd32();
    for (int i = 0; i < 32; i++) void'(rnd_bit());
    return lfsr;
  endfunction

  // ---------------------------------------------------------------- reset
  task automatic do_reset();
    upd_en = 1'b0; upd_pc = '0; upd_taken = 1'b0; pc = '0;
    r_umeta = '0; m_umeta = '0;
    @(negedge clk) rst_n = 1'b0;
    @(negedge clk) rst_n = 1'b1;
  endtask

  // ---------------------------------------------------------------- one branch
  task automatic branch(input logic [31:0] bpc, input logic taken);
    // cycle A: predict
    @(negedge clk);
    upd_en = 1'b0;
    pc     = bpc;
    #1;
    if ($isunknown({r_pred, r_meta}))
      $fatal(1, "[%s #%0d] X on predictor outputs pc=%h", trace_name, n_br, bpc);
    if (r_pred !== m_pred || r_meta !== m_meta) begin
      $display("MISMATCH [%s branch %0d] pc=%h taken=%b", trace_name, n_br, bpc, taken);
      $display("  RTL: pred=%b prov=%0d alt=%0d pred=%b alt_pred=%b idx=%h tag=%h",
               r_pred, r_meta.prov, r_meta.alt, r_meta.pred, r_meta.alt_pred, r_meta.idx, r_meta.tag);
      $display("  REF: pred=%b prov=%0d alt=%0d pred=%b alt_pred=%b idx=%h tag=%h",
               m_pred, m_meta.prov, m_meta.alt, m_meta.pred, m_meta.alt_pred, m_meta.idx, m_meta.tag);
      $fatal(1, "RTL vs reference mismatch");
    end
    if (r_pred   != taken) mis_tage++;
    prov_cnt[r_meta.prov]++;
    r_umeta = r_meta;
    m_umeta = m_meta;
    // cycle B: update
    @(negedge clk);
    pc        = rnd32();     // garbage on the predict port
    upd_en    = 1'b1;
    upd_pc    = bpc;
    upd_taken = taken;
    @(posedge clk);
    n_br++;
  endtask

  // ---------------------------------------------------------------- state compare
  int state_err;
  `define CMP_TAB(G) \
    for (int j = 0; j < 256; j++) begin \
      if (dut.g_tab[G].u_tab.g_tagged.valid_mem[j] !== u_ref.t_valid[G][j] || \
          dut.g_tab[G].u_tab.g_tagged.u_mem[j]     !== u_ref.t_u[G][j]     || \
          dut.g_tab[G].u_tab.ctr_mem[j]            !== u_ref.t_ctr[G][j]   || \
          (u_ref.t_valid[G][j] && dut.g_tab[G].u_tab.g_tagged.tag_mem[j] !== u_ref.t_tag[G][j])) begin \
        if (state_err < 5) $display("STATE MISMATCH T%0d[%0d]: rtl v=%b t=%h c=%b u=%b ref v=%b t=%h c=%b u=%b", G, j, \
          dut.g_tab[G].u_tab.g_tagged.valid_mem[j], dut.g_tab[G].u_tab.g_tagged.tag_mem[j], \
          dut.g_tab[G].u_tab.ctr_mem[j], dut.g_tab[G].u_tab.g_tagged.u_mem[j], \
          u_ref.t_valid[G][j], u_ref.t_tag[G][j], u_ref.t_ctr[G][j], u_ref.t_u[G][j]); \
        state_err++; \
      end \
    end

  task automatic check_state();
    @(negedge clk); upd_en = 1'b0;
    state_err = 0;
    for (int j = 0; j < 1024; j++)
      if (dut.T0[j] !== u_ref.T0[j]) begin
        if (state_err < 5) $display("STATE MISMATCH T0[%0d]: rtl %b ref %b", j, dut.T0[j], u_ref.T0[j]);
        state_err++;
      end
    `CMP_TAB(1)
    `CMP_TAB(2)
    `CMP_TAB(3)
    `CMP_TAB(4)
    if (dut.u_hash.ghr !== u_ref.ghr) begin
      $display("STATE MISMATCH GHR: rtl %h ref %h", dut.u_hash.ghr, u_ref.ghr);
      state_err++;
    end
    if (state_err != 0) $fatal(1, "[%s] %0d table/GHR entries differ", trace_name, state_err);
  endtask

  // ---------------------------------------------------------------- trace wrapper
  task automatic start_trace(input string name);
    trace_name = name;
    n_br = 0; mis_tage = 0;
    for (int i = 0; i <= 4; i++) prov_cnt[i] = 0;
    lfsr = 32'hACE1_2345 ^ name.len();
    do_reset();
  endtask

  task automatic end_trace();
    check_state();
    $display("%-12s %7d | %7d (%5.2f%%) | prov %0d/%0d/%0d/%0d/%0d",
             trace_name, n_br, mis_tage, 100.0 * mis_tage / n_br,
             prov_cnt[0], prov_cnt[1], prov_cnt[2], prov_cnt[3], prov_cnt[4]);
    tot_br += n_br; tot_tage += mis_tage;
  endtask

  // ---------------------------------------------------------------- traces
  // nested loops: inner trip 7, outer trip 13
  task automatic tr_loops();
    start_trace("loops");
    while (n_br < N_BR) begin
      for (int o = 0; o < 13 && n_br < N_BR; o++) begin
        for (int i = 0; i < 7 && n_br < N_BR; i++)
          branch(32'h0000_1040, i != 6);
        branch(32'h0000_1080, o != 12);
      end
    end
    end_trace();
  endtask

  // alternating T/NT on one branch, plus a period-3 branch
  task automatic tr_alternating();
    start_trace("alternating");
    for (int k = 0; n_br < N_BR; k++) begin
      branch(32'h0000_2000, k[0]);
      branch(32'h0000_2010, (k % 3) == 0);
    end
    end_trace();
  endtask

  // correlated at distance D (16..32 branches): branch B repeats branch A's
  // outcome after D-1 filler branches whose outcomes are fixed per position
  task automatic tr_correlated(input int D);
    logic a;
    start_trace($sformatf("corr_d%0d", D));
    while (n_br < N_BR) begin
      a = rnd_bit();
      branch(32'h0000_3000, a);
      for (int f = 0; f < D - 2; f++) branch(32'h0000_3100 + 4 * f, f[1]);
      branch(32'h0000_3800, a);
    end
    end_trace();
  endtask

  // LFSR-random outcomes on 16 PCs (unpredictable)
  task automatic tr_random();
    start_trace("lfsr_random");
    while (n_br < N_BR) branch(32'h0000_4000 + 4 * (rnd32() % 16), rnd_bit());
    end_trace();
  endtask

  // a "program" of 512 random PCs, each biased (85%) in its own direction;
  // exercises aliasing, allocation pressure and u-clearing
  task automatic tr_program();
    logic [31:0] pcs  [512];
    logic        bias [512];
    int k;
    start_trace("program512");
    for (int i = 0; i < 512; i++) begin pcs[i] = {rnd32()} & 32'h000F_FFFC; bias[i] = rnd_bit(); end
    while (n_br < N_BR) begin
      k = rnd32() % 512;
      branch(pcs[k], (rnd32() % 100 < 85) ? bias[k] : !bias[k]);
    end
    end_trace();
  endtask

  // board patterns: the same branch_trace.mem the board plays
  localparam int ROOM = 32, BOARD_RUN = 40000;
  localparam int PAT_LEN [4] = '{28, 2, 20, 31};     // same as trace_rom.sv
  logic [32:0] prog_rom [4 * ROOM];
  string       prog_names [4] = '{"brd_loop", "brd_altern", "brd_corr", "brd_mixed"};

  task automatic load_programs();
    string paths [2] = '{"rtl/board/branch_trace.mem", "../../rtl/board/branch_trace.mem"};
    int fd;
    foreach (paths[i]) begin
      fd = $fopen(paths[i], "r");
      if (fd != 0) begin
        $fclose(fd);
        $readmemh(paths[i], prog_rom);
        return;
      end
    end
    $fatal(1, "rtl/board/branch_trace.mem not found");
  endtask

  task automatic tr_real(input int sw);
    start_trace(prog_names[sw]);
    for (int i = 0; i < BOARD_RUN; i++)
      branch(prog_rom[sw * ROOM + i % PAT_LEN[sw]][31:0], prog_rom[sw * ROOM + i % PAT_LEN[sw]][32]);
    end_trace();
    $display("             board SW=%02b shows: %04h %04h", 2'(sw), 16'(mis_tage), 16'(n_br));
  endtask

  // ---------------------------------------------------------------- main
  initial begin
    rst_n = 1'b1;
    tot_br = 0; tot_tage = 0;
    $display("TAGE storage = %0d bits",
             (1 << BASE_IDX_W) * 2 + NUM_T * (1 << IDX_W) * (1 + TAG_W + CTR_W + 1));
    $display("trace        branch |  TAGE mispred    | provider T0/T1/T2/T3/T4");
    tr_loops();
    tr_alternating();
    tr_correlated(16);
    tr_correlated(24);
    tr_correlated(32);
    tr_random();
    tr_program();
    load_programs();
    for (int sw = 0; sw < 4; sw++) tr_real(sw);
    $display("%-12s %7d | %7d (%5.2f%%)", "TOTAL", tot_br,
             tot_tage, 100.0 * tot_tage / tot_br);
    $display("RTL matched tage_ref on every branch and every table entry.");
    $display("TEST PASSED");
    $finish;
  end

endmodule
