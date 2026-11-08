# -----------------------------------------------------------------------------
# run_sim.tcl
# Purpose : Batch behavioral simulation with xsim in the generated project.
#   vivado -mode batch -source scripts/run_sim.tcl                   (all sets)
#   vivado -mode batch -source scripts/run_sim.tcl -tclargs sim_1    (selected)
# Each simulation set runs to completion ($finish). A set passes only if its
# simulate.log contains "TEST PASSED" and no MISMATCH / ERROR / Fatal line.
# Exits with status 1 if any set fails.
# -----------------------------------------------------------------------------
set root [file normalize [file join [file dirname [info script]] ..]]
cd $root

if {![file exists vivado/tage.xpr]} {
  source [file join $root scripts create_project.tcl]
}
open_project vivado/tage.xpr

if {[llength $argv] > 0} {
  set sets $argv
} else {
  set sets {}
  foreach s [get_filesets -filter {FILESET_TYPE == SimulationSrcs}] {
    lappend sets [get_property NAME $s]
  }
  set sets [lsort $sets]
}

set failed {}
foreach fs $sets {
  puts "INFO: ===== simulating $fs ====="
  set rc [catch {launch_simulation -simset $fs -mode behavioral} msg]
  catch {close_sim -force -quiet}
  set log [file join $root vivado tage.sim $fs behav xsim simulate.log]
  set ok 0
  if {[file exists $log]} {
    set fh [open $log r]
    set txt [read $fh]
    close $fh
    set ok [expr {[string match "*TEST PASSED*" $txt] &&
                  ![regexp -line {^(MISMATCH|ERROR|Fatal|FATAL)} $txt]}]
    foreach line [split $txt "\n"] {
      if {[regexp {^(TEST |MISMATCH|ERROR|  trace|  board|  [a-z0-9_]+ +\||=== )} $line]} {
        puts "  $line"
      }
    }
  }
  if {$rc} { puts "WARNING: launch_simulation returned: $msg" }
  if {$ok} {
    puts "INFO: $fs PASSED"
  } else {
    puts "ERROR: $fs FAILED (log: $log)"
    lappend failed $fs
  }
}

close_project
if {[llength $failed] > 0} {
  puts "ERROR: failing simulation sets: $failed"
  exit 1
}
puts "INFO: all simulation sets passed: $sets"
exit 0
