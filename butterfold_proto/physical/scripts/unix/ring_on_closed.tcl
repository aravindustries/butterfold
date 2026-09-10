# Add the config-generated PDN core ring to the CLOSED power_ring build.
#
# The ring comes from pdngen with the values in config.json (PDN_CORE_RING*),
# not from hand-placed coordinates.  Only the 12 ACH tie/load nets that route
# on Metal4/Metal5 outside the core are rerouted; every other net is frozen,
# so the +0.039952 closure is preserved.
read_db $::env(BASE_ODB)
set block [ord::get_db_block]
proc pgcount {block} {
  array set n {RING 0 STRIPE 0 FOLLOWPIN 0 OTHER 0}
  foreach net [$block getNets] {
    set st [$net getSigType]
    if {$st ne "POWER" && $st ne "GROUND"} { continue }
    foreach sw [$net getSWires] {
      foreach w [$sw getWires] {
        set t [$w getWireShapeType]
        if {[info exists n($t)]} { incr n($t) } else { incr n(OTHER) }
      }
    }
  }
  return [list $n(RING) $n(STRIPE) $n(FOLLOWPIN) $n(OTHER)]
}
lassign [pgcount $block] r0 s0 f0 o0
puts "X_PG_BEFORE ring=$r0 stripe=$s0 followpin=$f0 other=$o0"
puts "X_IN INST [llength [$block getInsts]] BTERMS [llength [$block getBTerms]] NETS [llength [$block getNets]]"

# ---- 1. regenerate the PDN, this time with the core ring ----
add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
add_global_connection -net VDD -inst_pattern {.*u_lo.*u_sram} -pin_pattern VDD -power
add_global_connection -net VSS -inst_pattern {.*u_lo.*u_sram} -pin_pattern VSS -ground
add_global_connection -net VDD -inst_pattern {.*u_hi.*u_sram} -pin_pattern VDD -power
add_global_connection -net VSS -inst_pattern {.*u_hi.*u_sram} -pin_pattern VSS -ground
global_connect

# RING ONLY.  The existing stripes and followpins are already pdngen output
# from the original harden; regenerating them needs ~4000 shapes rebuilt over a
# fully routed 42k-instance database, which is what ran the process out of
# memory.  The ring is a closed loop and overlaps the existing M5 stripes at the
# east rail and the existing M4 stripes at the top rail, so it ties into the
# grid without the stripes being touched.
set_voltage_domain -name CORE -power VDD -ground VSS
define_pdn_grid -name ring_grid -starts_with POWER -voltage_domain CORE
# values straight from config.json PDN_CORE_RING_*
add_pdn_ring -grid ring_grid -layers "Metal4 Metal5" \
    -widths "2.0 2.0" -spacings "1.7 1.7" -core_offset "0.6 0.6"
add_pdn_connect -grid ring_grid -layers "Metal4 Metal5"
puts "X_PDNGEN ring-only"
pdngen

lassign [pgcount $block] r1 s1 f1 o1
puts "X_PG_AFTER ring=$r1 stripe=$s1 followpin=$f1 other=$o1"
if {$r1 == 0} { puts "X_ABORT pdngen produced no RING shapes"; exit 1 }
if {$f1 < [expr {$f0/2}]} { puts "X_ABORT followpins lost ($f0 -> $f1)"; exit 1 }

# ---- 2. reroute only the nets that collide with the new ring ----
set conflict {}
set fh [open $::env(CONFLICT_LIST) r]
while {[gets $fh line] >= 0} { set l [string trim $line]; if {$l ne ""} { lappend conflict $l } }
close $fh
puts "X_CONFLICT_LIST [llength $conflict]"

set wiped 0; set frozen 0; set nodnt 0; set missing 0
foreach n $conflict {
  set net [$block findNet $n]
  if {$net eq "NULL"} { incr missing; continue }
  set w [$net getWire]
  if {$w ne "NULL" && $w ne ""} { odb::dbWire_destroy $w; incr wiped }
  catch {$net clearGuides}
}
set wipe [list]
foreach n $conflict { lappend wipe $n }
foreach net [$block getNets] {
  set st [$net getSigType]
  if {$st eq "POWER" || $st eq "GROUND"} { continue }
  if {[lsearch -exact $wipe [$net getName]] >= 0} { continue }
  set w [$net getWire]
  if {$w ne "NULL" && $w ne ""} {
    if {[catch {$net setDoNotTouch true}]} { incr nodnt } else { incr frozen }
  }
}
puts "X_WIPED $wiped MISSING $missing FROZEN $frozen DNT_UNSUPPORTED $nodnt"
if {$nodnt > 0} { puts "X_ABORT setDoNotTouch unsupported"; exit 1 }

set probe ""
foreach net [$block getNets] {
  if {[$net getSigType] eq "POWER" || [$net getSigType] eq "GROUND"} { continue }
  if {[lsearch -exact $wipe [$net getName]] >= 0} { continue }
  set w [$net getWire]
  if {$w ne "NULL" && $w ne ""} { set probe [$net getName]; break }
}
puts "X_PROBE_NET $probe"

set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
puts "X_GRT"
global_route -congestion_iterations 50 -verbose
puts "X_DRT"
detailed_route -droute_end_iter 32 -or_seed 42 -verbose 1 -output_drc $::env(OUT_DIR)/drt.drc

foreach net [$block getNets] { catch {$net setDoNotTouch false} }
set pw [[$block findNet $probe] getWire]
puts "X_PROBE_WIRE_AFTER [expr {($pw ne "NULL" && $pw ne "") ? "PRESENT" : "GONE"}]"

# ---- 3. fill, connect, check, write ----
set fills {}; set decaps {}
foreach lib [[ord::get_db] getLibs] { foreach m [$lib getMasters] {
  set n [$m getName]
  if {[string match "gf180mcu_fd_sc_mcu9t5v0__fillcap_*" $n]} { lappend decaps $n }
  if {[string match "gf180mcu_fd_sc_mcu9t5v0__fill_*" $n]}    { lappend fills $n }
}}
catch {remove_fillers}
filler_placement [concat [lsort -decreasing $decaps] [lsort -decreasing $fills]]
global_connect
puts "X_PSM_VDD"; check_power_grid -net VDD
puts "X_PSM_VSS"; check_power_grid -net VSS
write_db      $::env(OUT_DIR)/filled.odb
write_def     $::env(OUT_DIR)/filled.def
write_verilog -include_pwr_gnd $::env(OUT_DIR)/butterfold_top.final.pnl.v
puts "X_DONE INST [llength [$block getInsts]] BTERMS [llength [$block getBTerms]]"
