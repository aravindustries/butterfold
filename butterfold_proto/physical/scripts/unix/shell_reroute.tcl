# Clear signal routing and re-route the repaired shelled design.
read_db $::env(ITER_DIR)/setup_closed.odb
set_thread_count 16
set block [ord::get_db_block]
set dw 0; set gd 0
foreach net [$block getNets] {
  set st [$net getSigType]
  if {$st eq "POWER" || $st eq "GROUND"} { continue }
  set w [$net getWire]
  if {$w ne "NULL" && $w ne ""} { catch {odb::dbWire_destroy $w}; incr dw }
  catch { set n [llength [$net getGuides]]; if {$n > 0} { $net clearGuides; incr gd $n } }
}
puts "X_CLEARED_WIRES $dw GUIDES $gd"
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
# GRT capacity de-rate.  0.3 (LibreLane default) costs ~3.4 ns of detour on
# this design; lower values give the router more tracks and shorter paths.
set adj 0.30
if {[info exists ::env(GRT_ADJ)] && $::env(GRT_ADJ) ne ""} { set adj $::env(GRT_ADJ) }
puts "X_GRT_ADJUSTMENT $adj"
foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer $adj }
puts "X_GRT"
global_route -congestion_iterations 50 -verbose
proc diode_count {} {
  set n 0
  foreach i [[ord::get_db_block] getInsts] {
    if {[string match "*__antenna" [[$i getMaster] getName]]} { incr n }
  }
  return $n
}
puts "X_ANTENNA_GRT_BEFORE [check_antennas] DIODE [diode_count]"
repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -iterations 3 -ratio_margin 10
puts "X_ANTENNA_GRT_AFTER [check_antennas] DIODE [diode_count]"
catch {detailed_placement -max_displacement {500 100}}
puts "X_DRT DIODE [diode_count]"
detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $::env(ITER_DIR)/drt.drc
write_db  $::env(ITER_DIR)/routed.odb
write_def $::env(ITER_DIR)/routed.def
puts "X_ROUTED_WRITTEN"
puts "X_ANTENNA_FINAL [check_antennas] DIODE [diode_count]"
puts "X_BTERMS [llength [$block getBTerms]]"
