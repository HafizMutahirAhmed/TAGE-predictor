# -----------------------------------------------------------------------------
# Makefile - convenience targets for the TAGE project
#   make lint      verilator --lint-only -Wall on rtl/ (top = nexys7_top)
#   make sim       Verilator 5 (--binary --timing, Verilog-2005 mode): tb_tage + all unit tests
#   make unit      Verilator unit tests only
#   make xsim      Vivado xsim (standalone xvlog/xelab/xsim): same tests
#   make project   create vivado/tage.xpr        (scripts/create_project.tcl)
#   make vsim      project-mode simulation       (scripts/run_sim.tcl)
#   make build     synth/impl/bitstream + reports (scripts/build.tcl)
#   make waves     CEP waveforms: waves/waves.vcd + waves/*.svg (tb_waves.v)
#   make clean
# -----------------------------------------------------------------------------
INC   := rtl/tage_defines.vh rtl/tage_funcs.vh
RTL   := rtl/tage_table.v rtl/tage_hash.v rtl/tage_predict.v \
         rtl/tage_update.v rtl/tage_top.v \
         rtl/board/trace_rom.v rtl/board/perf_counters.v rtl/board/seg7_driver.v \
         rtl/board/nexys7_top.v
TB    := tb/tage_ref.v tb/tb_tage.v
UNITS := tb_tage_table tb_tage_hash tb_tage_predict tage_tb tb_tage_update tb_perf_counters

BUILD := build
VLANG  := --default-language 1364-2005 -Irtl
VFLAGS := $(VLANG) --binary --timing -j 0 -Wno-fatal -Wno-lint -Wno-style --x-assign unique --x-initial unique

.PHONY: all lint sim unit xsim project vsim build clean waves

waves: $(INC) $(RTL) waves/tb_waves.v
	@mkdir -p $(BUILD)/tb_waves
	verilator $(VLANG) --binary --timing --trace -j 0 -Wno-fatal -Wno-lint -Wno-style --top-module tb_waves \
	  --Mdir $(BUILD)/tb_waves -o Vtb_waves $(filter-out rtl/board/%,$(RTL)) waves/tb_waves.v
	cd waves && ../$(BUILD)/tb_waves/Vtb_waves
	cd waves && python3 vcd2svg.py waves.vcd w1_clear_start.svg 0 400000 "W1a: reset -> clear FSM starts (one entry per clock)" clk rst_n ready t1_clearing t1_clr_idx:dec t0_clearing t0_clr_idx:dec
	cd waves && python3 vcd2svg.py waves.vcd w1_clear_end.svg 20380000 20620000 "W1b: T0 clears its last entry (1023) -> ready_o = 1 (T1..T4 finished after 256 clocks)" clk rst_n ready t1_clearing t0_clearing t0_clr_idx:dec
	cd waves && python3 vcd2svg.py waves.vcd w2_predict_update.svg 20540000 20780000 "W2/W3: predict (cycle A), update (cycle B), misprediction -> allocation in T1" clk pc pred prov:dec hit idx1 tag1 upd_en upd_taken mispredict t0_we t_we t1_wvalid t1_wtag t1_wctr:dec ghr

all: lint sim

lint:
	verilator --lint-only -Wall $(VLANG) -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM --top-module nexys7_top $(RTL)
	@echo "LINT CLEAN"

$(BUILD)/tb_tage/Vtb_tage: $(INC) $(RTL) $(TB)
	@mkdir -p $(BUILD)/tb_tage
	verilator $(VFLAGS) --top-module tb_tage --Mdir $(BUILD)/tb_tage -o Vtb_tage $(RTL) $(TB)

define UNIT_RULE
$(BUILD)/$(1)/V$(1): $(INC) $(RTL) tb/unit/$(1).v
	@mkdir -p $(BUILD)/$(1)
	verilator $(VFLAGS) --top-module $(1) --Mdir $(BUILD)/$(1) -o V$(1) $(RTL) tb/unit/$(1).v
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
	  src=../../tb/unit/$$t.v; [ $$t = tb_tage ] && src="$(addprefix ../../,$(TB))"; \
	  xvlog -i ../../rtl $(addprefix ../../,$(RTL)) $$src > xvlog_$$t.log || { cat xvlog_$$t.log; exit 1; }; \
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
