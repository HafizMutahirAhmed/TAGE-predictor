# -----------------------------------------------------------------------------
# Makefile - convenience targets for the TAGE project
#   make lint      verilator --lint-only -Wall on rtl/ (top = nexys7_top)
#   make sim       Verilator 5 (--binary --timing): tb_tage + all unit tests
#   make unit      Verilator unit tests only
#   make xsim      Vivado xsim (standalone xvlog/xelab/xsim): same tests
#   make project   create vivado/tage.xpr        (scripts/create_project.tcl)
#   make vsim      project-mode simulation       (scripts/run_sim.tcl)
#   make build     synth/impl/bitstream + reports (scripts/build.tcl)
#   make waves     CEP waveforms: waves/waves.vcd + waves/*.svg (tb_waves.sv)
#   make clean
# -----------------------------------------------------------------------------
RTL   := rtl/tage_pkg.sv rtl/tage_table.sv rtl/tage_hash.sv rtl/tage_predict.sv \
         rtl/tage_update.sv rtl/tage_top.sv \
         rtl/board/trace_rom.sv rtl/board/perf_counters.sv rtl/board/seg7_driver.sv \
         rtl/board/nexys7_top.sv
TB    := tb/tage_ref.sv tb/tb_tage.sv
UNITS := tb_tage_table tb_tage_hash tb_tage_predict tage_tb tb_tage_update tb_perf_counters

BUILD := build
VFLAGS := --binary --timing -j 0 -Wno-fatal -Wno-lint -Wno-style --x-assign unique --x-initial unique

.PHONY: all lint sim unit xsim project vsim build clean waves

waves: $(RTL) waves/tb_waves.sv
	@mkdir -p $(BUILD)/tb_waves
	verilator --binary --timing --trace -j 0 -Wno-fatal -Wno-lint -Wno-style --top-module tb_waves \
	  --Mdir $(BUILD)/tb_waves -o Vtb_waves $(filter-out rtl/board/%,$(RTL)) waves/tb_waves.sv
	cd waves && ../$(BUILD)/tb_waves/Vtb_waves
	cd waves && python3 vcd2svg.py waves.vcd w1_clear_start.svg 0 400000 "W1a: reset -> clear FSM starts (one entry per clock)" clk rst_n ready t1_clearing t1_clr_idx:dec t0_clearing t0_clr_idx:dec
	cd waves && python3 vcd2svg.py waves.vcd w1_clear_end.svg 20380000 20620000 "W1b: T0 clears its last entry (1023) -> ready_o = 1 (T1..T4 finished after 256 clocks)" clk rst_n ready t1_clearing t0_clearing t0_clr_idx:dec
	cd waves && python3 vcd2svg.py waves.vcd w2_predict_update.svg 20540000 20780000 "W2/W3: predict (cycle A), update (cycle B), misprediction -> allocation in T1" clk pc pred prov:dec hit idx1 tag1 upd_en upd_taken mispredict t0_we t_we t1_wvalid t1_wtag t1_wctr:dec ghr

all: lint sim

lint:
	verilator --lint-only -Wall -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM --top-module nexys7_top $(RTL)
	@echo "LINT CLEAN"

$(BUILD)/tb_tage/Vtb_tage: $(RTL) $(TB)
	@mkdir -p $(BUILD)/tb_tage
	verilator $(VFLAGS) --top-module tb_tage --Mdir $(BUILD)/tb_tage -o Vtb_tage $(RTL) $(TB)

define UNIT_RULE
$(BUILD)/$(1)/V$(1): $(RTL) tb/unit/$(1).sv
	@mkdir -p $(BUILD)/$(1)
	verilator $(VFLAGS) --top-module $(1) --Mdir $(BUILD)/$(1) -o V$(1) $(RTL) tb/unit/$(1).sv
endef
$(foreach u,$(UNITS),$(eval $(call UNIT_RULE,$(u))))

unit: $(foreach u,$(UNITS),$(BUILD)/$(u)/V$(u))
	@set -e; for u in $(UNITS); do $(BUILD)/$$u/V$$u; done

sim: unit $(BUILD)/tb_tage/Vtb_tage
	$(BUILD)/tb_tage/Vtb_tage

xsim:
	@mkdir -p $(BUILD)/xsim
	@set -e; cd $(BUILD)/xsim; \
	for t in $(UNITS) tb_tage; do \
	  src=../../tb/unit/$$t.sv; [ $$t = tb_tage ] && src="$(addprefix ../../,$(TB))"; \
	  xvlog -sv $(addprefix ../../,$(RTL)) $$src > xvlog_$$t.log || { cat xvlog_$$t.log; exit 1; }; \
	  xelab -debug off $$t -s $$t > xelab_$$t.log || { cat xelab_$$t.log; exit 1; }; \
	  xsim $$t -R -log xsim_$$t.log > /dev/null; \
	  grep -q "TEST PASSED" xsim_$$t.log || { cat xsim_$$t.log; exit 1; }; \
	  grep "TEST PASSED" xsim_$$t.log; \
	done

project:
	vivado -mode batch -nojournal -log vivado/create_project.log -source scripts/create_project.tcl

vsim:
	vivado -mode batch -nojournal -log vivado/run_sim.log -source scripts/run_sim.tcl

build:
	vivado -mode batch -nojournal -log vivado/build.log -source scripts/build.tcl

clean:
	rm -rf $(BUILD) .Xil *.jou *.log *.pb xsim.dir webtalk*
