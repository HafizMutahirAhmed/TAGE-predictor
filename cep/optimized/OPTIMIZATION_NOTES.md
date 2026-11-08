# CEP optimization: predictor tables in LUTRAM (Person 1)

This folder is a complete, self-contained copy of the project with the
optimization applied. The main project folder (`../../`) is the **baseline**
(the original OEL design) and is unchanged.

## 1. Baseline problem (evidence)

From `../../reports/` (baseline, 50 MHz constraint):

* All predictor storage (T0: 1024 x 2 bits, T1..T4: 4 x 256 x 13 bits =
  15,360 bits) is built from **flip-flops**: 15,587 FFs and 10,186 LUTs.
  The OEL spec says every entry is cleared in one reset cycle, and FPGA RAM
  cannot be cleared in one cycle, so Vivado could only use flip-flops
  (`LUT as Memory = 0`, `Block RAM = 0`).
* Reading one entry out of 256 flip-flops needs a 256:1 multiplexer per bit
  (LUT6 + MUXF7 + MUXF8 trees) spread over the chip.
* Critical path: `p_meta_reg[idx]` -> port B read mux -> tage_update ->
  `ctr_mem_reg[..]/CE`, **15.6 ns, 10 logic levels, 84% routing delay**.
  WNS = +3.72 ns at 20 ns, i.e. Fmax about 61 MHz. At 100 MHz the design
  failed timing (WNS = -1.06 ns), which is why the board uses an MMCM for 50 MHz.

## 2. What was changed

| File | Change |
|---|---|
| `rtl/tage_table.sv` | Memories are now plain arrays with `(* ram_style = "distributed" *)`, written only on the clock edge and never reset, so Vivado maps them to **LUTRAM** (RAMD64E). A **clear FSM** (`clearing`, `clr_idx`) writes the reset value into one entry per clock after reset; it owns the write port while it runs. New output `ready` (0 while clearing). Read ports are unchanged (combinational). |
| `rtl/tage_top.sv` | T0 is now a `tage_table` instance in its untagged form (`TAG_W=0, CTR_W=2, IDX_W=10, CTR_INIT=2'b10`) instead of 2048 flip-flops. New output `ready_o` = all 5 tables ready. |
| `rtl/board/nexys7_top.sv` | `tage_ready` comes from `ready_o` (was tied to 1); the state machine already waits for it in `S_INIT`. |
| `tb/tb_tage.sv` | After reset, checks `ready_o` is 0, then waits for it before sending branches. T0 is compared at `dut.u_t0.ctr_mem`. |
| `tb/unit/tb_tage_table.sv` | Checks `ready` is 0 after reset and rises after exactly 256 / 1024 clocks; the async-reset test first dirties the table so the clear really clears something. |

`tage_hash`, `tage_predict`, `tage_update`, `tage_pkg`, `tage_ref` and the
trace / counters / display are unchanged. The prediction logic is identical:
the same branch sequence gives exactly the same predictions as the baseline.

## 3. Expected effect (stated before the change)

* FFs drop by about 15k and the big read multiplexers disappear (a LUTRAM
  read is done inside the LUT), so LUTs drop strongly too.
* Shorter, more local critical path, so WNS / Fmax improve.
* Fewer toggling flip-flops, so dynamic power drops.
* Trade-offs: after reset the predictor needs 1024 clocks (20.5 us at
  50 MHz) before it can be used; the OEL rule "clear every entry in one
  reset cycle" becomes "clear every entry within 1024 cycles after reset";
  the user must wait for `ready_o`. Two read ports mean the RAM is
  duplicated (Vivado does this automatically).

## 4. Results (same device xc7a100t, same XDC, same 50 MHz clock)

| Metric | Baseline | Optimized | Change |
|---|---|---|---|
| Slice LUTs | 10,186 (16.07%) | 1,138 (1.79%) | -88.8% |
| &nbsp;&nbsp;LUT as logic | 10,186 | 434 | |
| &nbsp;&nbsp;LUT as memory (LUTRAM) | 0 | 704 (RAMD64E) | |
| Flip-flops | 15,587 (12.29%) | 275 (0.22%) | -98.2% |
| BRAM / DSP | 0 / 0 | 0 / 0 | same |
| WNS / TNS (20 ns) | +3.720 / 0 ns | +9.478 / 0 ns | +5.76 ns slack |
| Critical path delay | 15.59 ns (10 levels, 84% route) | 10.41 ns (6 levels, 85% route) | -33% |
| Max frequency (1 / (20 - WNS)) | about 61 MHz | about 95 MHz | +55% |
| Total on-chip power | 0.292 W | 0.216 W | -26% |
| &nbsp;&nbsp;dynamic / static | 0.194 / 0.098 W | 0.118 / 0.097 W | dynamic -39% |
| Prediction latency | 1 cycle (combinational) | 1 cycle | same |
| Throughput (2 cycles/branch) | 25 M branches/s at 50 MHz | 25 M/s at 50 MHz (up to about 47 M/s at Fmax) | |
| Ready after reset | 1 cycle | 1024 cycles (20.5 us) | worse (trade-off) |
| Mispredictions, 300,016 test branches | 16,757 | 16,757 | identical |
| Board display (SW 00/01/10/11) | 000B / 0002 / 000C / 000E of 9C40 | same | identical |

New critical path: `trace_rom q_reg` (pc) -> hash -> LUTRAM read
(RAMD64E) -> tag compare / provider select -> `p_tage_reg`, i.e. the
**predict** path is now the longest, no longer the update/write path.

Fmax is estimated from the timing report as 1 / (20 ns - WNS). The 50 MHz
constraint was kept on purpose so both designs are compared under the same
constraints (CEP requirement 7).

## 5. Verification

* `make sim` (Verilator) and `make xsim` (Vivado simulator): all 6 unit tests
  and `tb_tage` pass. `tb_tage` compares the RTL with `tage_ref` on every
  branch (prediction + meta) and every table entry after each trace.
* Board-level simulation of `nexys7_top` gives the same display values as the
  baseline.
* `make waves` writes `waves/waves.vcd` and three figures:
  * `w1_clear_start.png`: `rst_n` goes high, `ready` is 0, the clear FSM
    starts and `clr_idx` counts 0, 1, 2, ... one entry per clock.
  * `w1_clear_end.png`: T0's `clr_idx` reaches 1023, `t0_clearing` falls and
    `ready_o` rises (T1..T4 already finished after 256 clocks).
  * `w2_predict_update.png`: cycle A, `pc = 1040` and `pred` is valid in the
    same cycle (1-cycle latency, `prov = 0` = T0). Cycle B, `upd_en = 1`,
    `t0_we` trains T0 and the GHR shifts. For `pc = 2000` T0 predicts taken
    but the branch is not taken: `mispredict = 1`, so `t_we = 1` (T1),
    `t1_wvalid = 1`, `t1_wtag = 0A` (the tag from cycle A), `t1_wctr = 3`
    (weakly not taken), which is rule 3 (allocation).

## 6. How to run (from this folder)

```
make sim       # all tests (Verilator)
make xsim      # all tests (Vivado xsim)
make waves     # waveform figures in waves/
make project   # Vivado project in ./vivado
make build     # synthesis + implementation + bitstream + reports/
```

The bitstream is `bitstream/nexys7_top.bit`. On the board it behaves like the
baseline; LED7 is on for about 20 us after reset/BTNC while the tables clear,
which is too short to see.
