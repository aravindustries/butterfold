# Stage 2: route the shelled core.  Existing signal routing is destroyed first
# (detailed_route cannot run over prior routing - DRT-1231), then the whole
# design including the 112 new ACH nets is routed fresh.  PG nets, and so the
# generated core ring, are left untouched.
read_db $::env(OUT_DIR)/shell_placed.odb
set_thread_count 16
set block [ord::get_db_block]

set dw 0; set gd 0
foreach net [$block getNets] {
  set st [$net getSigType]
  if {$st eq "POWER" || $st eq "GROUND"} { continue }
  set w [$net getWire]
  if {$w ne "NULL" && $w ne ""} { catch {odb::dbWire_destroy $w}; incr dw }
  catch {
    set n [llength [$net getGuides]]
    if {$n > 0} { $net clearGuides; incr gd $n }
  }
}
puts "X_CLEARED_WIRES $dw GUIDES $gd"

set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
foreach layer {Metal2 Metal3 Metal4 Metal5} {
  set_global_routing_layer_adjustment $layer 0.3
}
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
detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 \
    -output_drc $::env(OUT_DIR)/drt.drc
write_db  $::env(OUT_DIR)/shell_routed.odb
write_def $::env(OUT_DIR)/shell_routed.def
puts "X_ROUTED_WRITTEN"
puts "X_ANTENNA_FINAL [check_antennas] DIODE [diode_count]"
puts "X_BTERMS [llength [$block getBTerms]]"
puts "X_ROUTE_DONE"
