# -----------------------------------------------------------------------------
# build.tcl
# Purpose : Synthesis, implementation (opt/place/route) and bitstream for
#           nexys7_top using the project runs (so results show up in the GUI),
#           then reports into reports/ and the bitstream into bitstream/.
#   vivado -mode batch -source scripts/build.tcl [-tclargs <jobs>]
# Reports : utilization(.rpt, _hier), timing_summary, power, methodology, drc,
#           ram_utilization (LUTRAM check)
# Exits 1 on run failure, timing failure (WNS < 0 or WHS < 0) or critical
# warnings in the run logs.
# -----------------------------------------------------------------------------
set root [file normalize [file join [file dirname [info script]] ..]]
cd $root
set jobs [expr {[llength $argv] > 0 ? [lindex $argv 0] : 4}]

if {![file exists vivado/tage.xpr]} {
  source [file join $root scripts create_project.tcl]
}
open_project vivado/tage.xpr
file mkdir reports bitstream

reset_run synth_1
launch_runs synth_1 -jobs $jobs
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
  puts "ERROR: synthesis failed"
  exit 1
}

launch_runs impl_1 -to_step write_bitstream -jobs $jobs
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
  puts "ERROR: implementation failed"
  exit 1
}

open_run impl_1
report_utilization                -file reports/utilization.rpt
report_utilization -hierarchical  -file reports/utilization_hier.rpt
report_ram_utilization            -file reports/ram_utilization.rpt
report_timing_summary -max_paths 10 -report_unconstrained -file reports/timing_summary.rpt
report_power                      -file reports/power.rpt
report_methodology                -file reports/methodology.rpt
report_drc                        -file reports/drc.rpt
check_timing -verbose             -file reports/check_timing.rpt

set wns [get_property STATS.WNS [get_runs impl_1]]
set whs [get_property STATS.WHS [get_runs impl_1]]
set tns [get_property STATS.TNS [get_runs impl_1]]

set bit [glob -nocomplain vivado/tage.runs/impl_1/*.bit]
if {[llength $bit] == 1} {
  file copy -force [lindex $bit 0] bitstream/nexys7_top.bit
}

# count critical warnings in the run logs
set crit 0
foreach run {synth_1 impl_1} {
  set lf [file join vivado tage.runs $run runme.log]
  if {[file exists $lf]} {
    set fh [open $lf r]
    foreach line [split [read $fh] "\n"] {
      if {[string match "CRITICAL WARNING:*" $line]} { incr crit; puts $line }
    }
    close $fh
  }
}

set fmax [expr {1000.0 / (10.0 - $wns)}]
puts [format "INFO: WNS = %.3f ns  TNS = %.3f ns  WHS = %.3f ns  Fmax(est) = %.1f MHz" $wns $tns $whs $fmax]
puts "INFO: critical warnings in run logs: $crit"
puts "INFO: bitstream: [file normalize bitstream/nexys7_top.bit]"

set fh [open reports/summary.txt w]
puts $fh [format "WNS_ns %.3f\nTNS_ns %.3f\nWHS_ns %.3f\nFmax_est_MHz %.1f\ncritical_warnings %d" $wns $tns $whs $fmax $crit]
close $fh

close_project
if {$wns < 0 || $whs < 0} { puts "ERROR: timing not met"; exit 1 }
if {$crit > 0}            { puts "ERROR: critical warnings present"; exit 1 }
if {[llength $bit] != 1}  { puts "ERROR: no bitstream"; exit 1 }
exit 0
