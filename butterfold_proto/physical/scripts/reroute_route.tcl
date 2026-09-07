# Re-route after the setup ECO.
#
# repair_timing moved and added cells, so the existing detailed routing is
# stale.  It must be DESTROYED before re-routing: running detailed_route over
# a database that still carries its old routing fails with DRT-1231 ("pin has
# no access point").  This mirrors 01_repair_legalize_grt.tcl, which clears
# wires and guides on every non-PG net before GRT.
read_db $::env(OUT_DIR)/setup_closed.odb
set_thread_count 16
file mkdir $::env(OUT_DIR)/route
set block [ord::get_db_block]

set dw 0; set gd 0
foreach net [$block getNets] {
  set st [$net getSigType]
  if {$st eq "POWER" || $st eq "GROUND"} { continue }
  set w [$net getWire]
  if {$w ne "NULL" && $w ne ""} { catch {odb::dbWire_destroy $w}; incr dw }
  catch {
    set nguid [llength [$net getGuides]]
    if {$nguid > 0} { $net clearGuides; incr gd $nguid }
  }
}
puts "X_CLEARED_WIRES $dw GUIDES $gd"
write_db $::env(OUT_DIR)/route/clean_unrouted.odb

set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
foreach layer {Metal2 Metal3 Metal4 Metal5} {
  set_global_routing_layer_adjustment $layer 0.3
}
puts "X_GRT"
global_route -congestion_iterations 50 -verbose
write_db $::env(OUT_DIR)/route/grt.odb

proc diode_count {} {
  set n 0
  foreach inst [[ord::get_db_block] getInsts] {
    if {[string match "*__antenna" [[$inst getMaster] getName]]} { incr n }
  }
  return $n
}

puts "X_ANTENNA_GRT_BEFORE [check_antennas] DIODE [diode_count]"
repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -iterations 3 -ratio_margin 10
puts "X_ANTENNA_GRT_AFTER [check_antennas] DIODE [diode_count]"
catch {detailed_placement -max_displacement {500 100}}
catch {check_placement -verbose}

puts "X_DRT DIODE [diode_count]"
detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 \
    -output_drc $::env(OUT_DIR)/route/drt-run-0.drc
write_db  $::env(OUT_DIR)/route/routed.odb
write_def $::env(OUT_DIR)/route/routed.def
puts "X_ROUTED_WRITTEN"
puts "X_ANTENNA_FINAL [check_antennas] DIODE [diode_count]"
check_antennas -verbose -report_file $::env(OUT_DIR)/route/antenna_final.rpt
puts "X_ROUTE_DONE"
