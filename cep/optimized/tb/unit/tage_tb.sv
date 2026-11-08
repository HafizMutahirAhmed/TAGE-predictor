// Self-checking testbench for tage_hash + tage_predict.
//   Part A - tage_hash    : reset value, GHR shifting, idx/tag vs. an
//                           independent reference model, async reset.
//   Part B - tage_predict : provider/alternate selection corner cases plus an
//                           exhaustive sweep of all 16 hit patterns.
// Prints PASS/FAIL with a check count at the end.
//
// In Vivado: type "run all" in the Tcl console (the test needs ~2.2 us, longer
// than the default 1000 ns).
// =============================================================================
`timescale 1ns/1ps

module tage_tb;

    localparam IDX_W  = 8;
    localparam TAG_W  = 8;
    localparam CTR_W  = 3;
    localparam GHR_W  = 32;
    localparam HL1 = 4, HL2 = 8, HL3 = 16, HL4 = 32;
    localparam META_W = 3 + 3 + 4*IDX_W + 4*TAG_W + 1 + 1;

    localparam [CTR_W-1:0] STRONG_T  = 3'b111;
    localparam [CTR_W-1:0] WEAK_T    = 3'b100;
    localparam [CTR_W-1:0] WEAK_NT   = 3'b011;
    localparam [CTR_W-1:0] STRONG_NT = 3'b000;

    // -------------------------------------------------------------------------
    // Clock / reset
    // -------------------------------------------------------------------------
    reg clk;
    reg rst_n;
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg  [31:0]        pc;
    reg                update_en;
    reg                actual_taken;
    wire [4*IDX_W-1:0] hash_idx;
    wire [4*TAG_W-1:0] hash_tag;

    reg                t0_ctr_msb;
    reg  [4:1]         t_valid;
    reg  [4*TAG_W-1:0] t_tag;
    reg  [4*CTR_W-1:0] t_ctr;
    reg  [4:1]         t_u;
    wire               pred;
    wire [META_W-1:0]  meta;

    tage_hash #(
        .IDX_W(IDX_W), .TAG_W(TAG_W),
        .HIST_LEN_1(HL1), .HIST_LEN_2(HL2), .HIST_LEN_3(HL3), .HIST_LEN_4(HL4)
    ) u_hash (
        .clk(clk), .rst_n(rst_n), .pc(pc),
        .idx(hash_idx), .tag(hash_tag),
        .update_en(update_en), .actual_taken(actual_taken)
    );

    tage_predict #(
        .IDX_W(IDX_W), .TAG_W(TAG_W), .CTR_W(CTR_W)
    ) u_predict (
        .t0_ctr_msb(t0_ctr_msb), .t_valid(t_valid), .t_tag(t_tag),
        .t_ctr(t_ctr), .t_u(t_u),
        .hash_idx(hash_idx), .hash_tag(hash_tag),
        .pred(pred), .meta(meta)
    );

    // Unpack meta (layout documented in tage_predict.v)
    wire [2:0]         m_prov     = meta[META_W-1 -: 3];
    wire [2:0]         m_alt      = meta[META_W-4 -: 3];
    wire [4*IDX_W-1:0] m_idx      = meta[2 + 4*TAG_W +: 4*IDX_W];
    wire [4*TAG_W-1:0] m_tag      = meta[2 +: 4*TAG_W];
    wire               m_pred     = meta[1];
    wire               m_alt_pred = meta[0];

    // -------------------------------------------------------------------------
    // Checking helpers
    // -------------------------------------------------------------------------
    integer errors;
    integer checks;

    task check;
        input          ok;
        input [8*40:1] msg;
        begin
            checks = checks + 1;
            if (ok !== 1'b1) begin
                errors = errors + 1;
                $display("[%0t] FAIL: %0s", $time, msg);
            end
        end
    endtask

    // Independent reference for the hash (written straight from the spec)
    reg [GHR_W-1:0] ref_ghr;

    function [7:0] ref_fold(input [GHR_W-1:0] h, input integer len);
        integer b;
        begin
            ref_fold = 8'h00;
            for (b = 0; b < len; b = b + 1)
                ref_fold[b % 8] = ref_fold[b % 8] ^ h[b];
        end
    endfunction

    function integer hist_len(input integer t);
        hist_len = (t == 1) ? HL1 : (t == 2) ? HL2 : (t == 3) ? HL3 : HL4;
    endfunction

    task check_hash;
        input [8*24:1] ctx;
        integer   t;
        reg [7:0] f, exp_idx, exp_tag;
        begin
            for (t = 1; t <= 4; t = t + 1) begin
                f       = ref_fold(ref_ghr, hist_len(t));
                exp_idx = pc[9:2]   ^ f;
                exp_tag = pc[17:10] ^ {f[6:0], f[7]};
                checks  = checks + 2;
                if (hash_idx[(t-1)*8 +: 8] !== exp_idx) begin
                    errors = errors + 1;
                    $display("[%0t] FAIL %0s: idx[%0d]=%h expected %h",
                             $time, ctx, t, hash_idx[(t-1)*8 +: 8], exp_idx);
                end
                if (hash_tag[(t-1)*8 +: 8] !== exp_tag) begin
                    errors = errors + 1;
                    $display("[%0t] FAIL %0s: tag[%0d]=%h expected %h",
                             $time, ctx, t, hash_tag[(t-1)*8 +: 8], exp_tag);
                end
            end
        end
    endtask

    // Compare predict outputs against expected values
    task check_predict;
        input [8*24:1] ctx;
        input [2:0]    exp_prov;
        input [2:0]    exp_alt;
        input          exp_pred;
        input          exp_alt_pred;
        begin
            #1;
            checks = checks + 1;
            if (m_prov !== exp_prov || m_alt !== exp_alt ||
                pred !== exp_pred || m_pred !== pred ||
                m_alt_pred !== exp_alt_pred ||
                m_idx !== hash_idx || m_tag !== hash_tag) begin
                errors = errors + 1;
                $display("[%0t] FAIL %0s: prov=%0d alt=%0d pred=%b alt_pred=%b | expected prov=%0d alt=%0d pred=%b alt_pred=%b",
                         $time, ctx, m_prov, m_alt, pred, m_alt_pred,
                         exp_prov, exp_alt, exp_pred, exp_alt_pred);
            end
        end
    endtask

    // Make table t hit (valid, matching tag) with the given counter
    task set_hit;
        input integer     t;
        input [CTR_W-1:0] ctr;
        begin
            t_valid[t]                    = 1'b1;
            t_tag[(t-1)*TAG_W +: TAG_W]   = hash_tag[(t-1)*TAG_W +: TAG_W];
            t_ctr[(t-1)*CTR_W +: CTR_W]   = ctr;
        end
    endtask

    task clear_tables;
        begin
            t_valid = 4'b0;
            t_tag   = {4*TAG_W{1'b0}};
            t_ctr   = {4*CTR_W{1'b0}};
            t_u     = 4'b0;
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    integer   n, m, t;
    reg [2:0] ep, ea;

    initial begin
        $display("==================================================");
        $display("  Member 2 verification: tage_hash + tage_predict");
        $display("==================================================");

        errors       = 0;
        checks       = 0;
        rst_n        = 1'b0;
        pc           = 32'h0040_8000;
        update_en    = 1'b0;
        actual_taken = 1'b0;
        t0_ctr_msb   = 1'b0;
        ref_ghr      = {GHR_W{1'b0}};
        clear_tables;

        repeat (2) @(posedge clk);
        @(negedge clk) rst_n = 1'b1;

        // ===================== Part A: tage_hash =====================
        #1 check(u_hash.ghr == 32'h0, "A0: GHR not zero after reset");
        check_hash("A0 reset");

        // A1: one taken branch shifts in at bit 0
        @(negedge clk) begin update_en = 1'b1; actual_taken = 1'b1; end
        @(posedge clk) ref_ghr = {ref_ghr[GHR_W-2:0], 1'b1};
        @(negedge clk) update_en = 1'b0;
        #1 check(u_hash.ghr == 32'h1, "A1: taken did not shift into bit 0");
        check_hash("A1");

        // A2: update_en low must hold the GHR
        @(negedge clk) actual_taken = 1'b1;
        @(posedge clk);
        #1 check(u_hash.ghr == ref_ghr, "A2: GHR changed with update_en=0");

        // A3: 200 random updates and PCs, compared every cycle
        for (n = 0; n < 200; n = n + 1) begin
            @(negedge clk) begin
                pc           = $random;
                update_en    = ($random & 3) != 0;
                actual_taken = $random & 1;
            end
            #1 check_hash("A3 random");
            @(posedge clk) if (update_en) ref_ghr = {ref_ghr[GHR_W-2:0], actual_taken};
            #1 check(u_hash.ghr == ref_ghr, "A3: GHR mismatch vs reference");
        end

        // A4: asynchronous reset clears a non-zero GHR
        @(negedge clk) update_en = 1'b0;
        #2 rst_n = 1'b0;
        #1 check(u_hash.ghr == 32'h0, "A4: async reset did not clear GHR");
        ref_ghr = {GHR_W{1'b0}};
        @(negedge clk) rst_n = 1'b1;

        // ===================== Part B: tage_predict =====================
        pc = 32'h0040_8000;
        #1;

        // B1: no tagged hits -> everything from T0
        clear_tables; t0_ctr_msb = 1'b0;
        check_predict("B1 no hit, T0=NT", 3'd0, 3'd0, 1'b0, 1'b0);
        t0_ctr_msb = 1'b1;
        check_predict("B1 no hit, T0=T",  3'd0, 3'd0, 1'b1, 1'b1);

        // B2: single hit on T3 -> alt falls back to T0
        clear_tables; t0_ctr_msb = 1'b0;
        set_hit(3, WEAK_T);
        check_predict("B2 T3 only", 3'd3, 3'd0, 1'b1, 1'b0);

        // B3: hits on T1, T3, T4 -> prov=T4, alt=T3 (T1 ignored)
        set_hit(1, STRONG_NT);
        set_hit(4, STRONG_T);
        check_predict("B3 T1+T3+T4", 3'd4, 3'd3, 1'b1, 1'b1);

        // B4: alt direction comes from the alternate, not the provider
        t_ctr[2*CTR_W +: CTR_W] = WEAK_NT;          // T3 counter
        check_predict("B4 prov T, alt NT", 3'd4, 3'd3, 1'b1, 1'b0);

        // B5: valid but tag mismatch is NOT a hit
        clear_tables;
        set_hit(2, STRONG_T);
        t_valid[4] = 1'b1;
        t_tag[3*TAG_W +: TAG_W] = ~hash_tag[3*TAG_W +: TAG_W];
        t_ctr[3*CTR_W +: CTR_W] = STRONG_T;
        check_predict("B5 T4 tag mismatch", 3'd2, 3'd0, 1'b1, 1'b0);

        // B6: matching tag but valid=0 is NOT a hit
        clear_tables;
        t_tag[3*TAG_W +: TAG_W] = hash_tag[3*TAG_W +: TAG_W];   // valid stays 0
        t_ctr[3*CTR_W +: CTR_W] = STRONG_T;
        set_hit(1, STRONG_NT);
        check_predict("B6 T4 invalid", 3'd1, 3'd0, 1'b0, 1'b0);

        // B7: adjacent pair T1+T2
        set_hit(2, WEAK_T);
        check_predict("B7 T1+T2", 3'd2, 3'd1, 1'b1, 1'b0);

        // B8: all four hit -> prov=T4, alt=T3
        clear_tables; t0_ctr_msb = 1'b1;
        set_hit(1, STRONG_NT);
        set_hit(2, STRONG_NT);
        set_hit(3, STRONG_T);
        set_hit(4, STRONG_NT);
        check_predict("B8 all hit", 3'd4, 3'd3, 1'b0, 1'b1);

        // B9: exhaustive sweep of all 16 hit patterns.
        // Odd tables predict taken, even tables not taken.
        for (m = 0; m < 16; m = m + 1) begin
            clear_tables;
            t0_ctr_msb = m[0];
            ep = 3'd0;
            ea = 3'd0;
            for (t = 1; t <= 4; t = t + 1)
                if (m[t-1]) set_hit(t, (t % 2 != 0) ? STRONG_T : STRONG_NT);
            for (t = 4; t >= 1; t = t - 1)
                if (m[t-1]) begin
                    if (ep == 3'd0)      ep = t;
                    else if (ea == 3'd0) ea = t;
                end
            check_predict("B9 sweep", ep, ea,
                          (ep == 3'd0) ? t0_ctr_msb : ep[0],
                          (ea == 3'd0) ? t0_ctr_msb : ea[0]);
        end

        // ===================== Summary =====================
        $display("==================================================");
        if (errors == 0)
            $display("  PASS: all %0d checks passed", checks);
        else
            $display("  FAIL: %0d of %0d checks failed", errors, checks);
        $display("==================================================");
        if (errors == 0) $display("TEST PASSED: tage_tb");
        else             $fatal(1, "TEST FAILED: tage_tb");
        $finish;
    end

    // Safety net against a hung simulation
    initial begin
        #100000;
        $display("TIMEOUT");
        $finish;
    end

endmodule