# -----------------------------------------------------------------------------
# create_project.tcl
# Purpose : Generate the Vivado project vivado/tage.xpr from the sources.
#   vivado -mode batch -source scripts/create_project.tcl
#   sources_1 : rtl/*.sv, rtl/board/*.sv        top = nexys7_top
#               rtl/board/branch_trace.mem      (trace_rom $readmemh)
#   constrs_1 : constraints/nexys7_a100t.xdc
#   sim_1     : tb/*.sv                         top = tb_tage
#   sim_<unit>: tb/unit/<unit>.sv               one simulation set per unit test
# All .sv files use file type SystemVerilog. Re-running recreates the project.
# -----------------------------------------------------------------------------
set root [file normalize [file join [file dirname [info script]] ..]]
cd $root

create_project tage ./vivado -part xc7a100tcsg324-1 -force

# Board file is optional: only set it if the Digilent board files are installed.
if {[catch {
  set bp [get_board_parts -quiet digilentinc.com:nexys-a7-100t:*1.3]
  if {[llength $bp] > 0} {
    set_property board_part [lindex $bp 0] [current_project]
    puts "INFO: board_part set to [lindex $bp 0]"
  } else {
    puts "INFO: Nexys A7-100T board file not installed, using part only"
  }
} err]} {
  puts "INFO: board_part not set ($err)"
}

set_property target_language Verilog   [current_project]
set_property simulator_language Mixed  [current_project]
set_property default_lib xil_defaultlib [current_project]

# ---- design sources (package first)
set rtl_files [concat [list rtl/tage_pkg.sv] \
                      [lsort [lsearch -all -inline -not [glob rtl/*.sv] rtl/tage_pkg.sv]] \
                      [lsort [glob rtl/board/*.sv]]]
add_files -norecurse -fileset sources_1 $rtl_files
set_property file_type SystemVerilog [get_files -of_objects [get_filesets sources_1] *.sv]
set_property top nexys7_top [get_filesets sources_1]
# branch trace for trace_rom ($readmemh finds it because it is a project source)
add_files -norecurse -fileset sources_1 rtl/board/branch_trace.mem

# ---- constraints
add_files -norecurse -fileset constrs_1 constraints/nexys7_a100t.xdc
set_property target_constrs_file [get_files constraints/nexys7_a100t.xdc] [get_filesets constrs_1]

# ---- main simulation set
add_files -norecurse -fileset sim_1 [lsort [glob tb/*.sv]]
set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]
set_property top tb_tage [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]

# ---- unit-test simulation sets
foreach f [lsort [glob tb/unit/*.sv]] {
  set top [file rootname [file tail $f]]
  set fs  "sim_[string range $top 3 end]"
  create_fileset -simset $fs
  add_files -norecurse -fileset $fs $f
  set_property file_type SystemVerilog [get_files -of_objects [get_filesets $fs] *.sv]
  set_property top $top [get_filesets $fs]
  set_property top_lib xil_defaultlib [get_filesets $fs]
  set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets $fs]
}
current_fileset -simset [get_filesets sim_1]

update_compile_order -fileset sources_1
foreach fs [get_filesets -filter {FILESET_TYPE == SimulationSrcs}] {
  update_compile_order -fileset $fs
}

# ---- run settings
set_property strategy {Vivado Synthesis Defaults} [get_runs synth_1]
set_property strategy {Vivado Implementation Defaults} [get_runs impl_1]

puts "INFO: created [file join $root vivado tage.xpr]"
puts "INFO: simulation sets: [get_filesets -filter {FILESET_TYPE == SimulationSrcs}]"
close_project
