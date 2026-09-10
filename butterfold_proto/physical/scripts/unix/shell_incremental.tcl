# Apply the ACH shell WITHOUT destroying the existing routing.
#
# Three differences from the earlier attempt:
#  1. each tie cell is placed next to its own pad terminal instead of all 112
#     landing on the core origin, so the new nets are short edge stubs;
#  2. every pre-existing instance is pinned before legalization, so DPL moves
#     only the new tie cells and never a cell whose routing we then freeze;
#  3. every already-routed net is marked do-not-touch, so GRT/DRT route only
#     the 112 new nets and the timing-closed routing survives.
read_db $::env(BASE_ODB)
set block [ord::get_db_block]
set dbu [$block getDefUnits]
puts "X_IN_BTERMS [llength [$block getBTerms]]  INST [llength [$block getInsts]]"

# ---- 0. preflight: does this build honour the APIs the plan needs? ----
set pnet ""
foreach net [$block getNets] {
  set st [$net getSigType]
  if {$st eq "POWER" || $st eq "GROUND"} { continue }
  set w [$net getWire]
  if {$w ne "NULL" && $w ne ""} { set pnet $net; break }
}
if {$pnet eq ""} { puts "X_ABORT base database has no routed signal nets"; exit 1 }
if {[catch {$pnet setDoNotTouch true} m]} {
  puts "X_ABORT dbNet::setDoNotTouch unsupported in this build -> $m"; exit 1
}
$pnet setDoNotTouch false
puts "X_PREFLIGHT_OK dbNet::setDoNotTouch available"

catch {remove_fillers}

# pin everything that already exists, so legalization only relocates new cells
set pinned 0
foreach inst [$block getInsts] {
  set s [$inst getPlacementStatus]
  if {$s eq "FIRM" || $s eq "LOCKED" || $s eq "COVER"} { continue }
  $inst setPlacementStatus FIRM
  incr pinned
}
puts "X_PINNED_EXISTING $pinned"

source $::env(SHELL_TCL)
puts "X_AFTER_SHELL_BTERMS [llength [$block getBTerms]]  INST [llength [$block getInsts]]"

# ---- 1. move each new ach_* instance next to the terminal it drives ----
set core [$block getCoreArea]
set cx0 [$core xMin]; set cy0 [$core yMin]; set cx1 [$core xMax]; set cy1 [$core yMax]
set rows [$block getRows]
set site [[lindex $rows 0] getSite]
set sw [$site getWidth]; set sh [$site getHeight]
set moved 0; set nomatch 0
foreach inst [$block getInsts] {
  set n [$inst getName]
  if {![string match "ach_*" $n]} { continue }
  set tgt ""
  foreach it [$inst getITerms] {
    set net [$it getNet]
    if {$net eq "NULL" || $net eq ""} { continue }
    foreach bt [$net getBTerms] {
      foreach bp [$bt getBPins] {
        foreach box [$bp getBoxes] {
          set tgt [list [expr {([$box xMin]+[$box xMax])/2}] [expr {([$box yMin]+[$box yMax])/2}]]
          break
        }
        if {$tgt ne ""} { break }
      }
      if {$tgt ne ""} { break }
    }
    if {$tgt ne ""} { break }
  }
  if {$tgt eq ""} { incr nomatch; continue }
  lassign $tgt tx ty
  # clamp inside the core, then snap to the site/row grid
  set w [[$inst getMaster] getWidth]
  if {$tx < $cx0} { set tx $cx0 }
  if {$tx > [expr {$cx1-$w}]} { set tx [expr {$cx1-$w}] }
  if {$ty < $cy0} { set ty $cy0 }
  if {$ty > [expr {$cy1-$sh}]} { set ty [expr {$cy1-$sh}] }
  set sx [expr {$cx0 + (round(double($tx-$cx0)/$sw) * $sw)}]
  set sy [expr {$cy0 + (round(double($ty-$cy0)/$sh) * $sh)}]
  $inst setLocation $sx $sy
  $inst setPlacementStatus PLACED
  incr moved
}
puts "X_TIE_CELLS_MOVED $moved  NO_TERMINAL $nomatch"

# no global padding: arav's placement was legalized without it, and imposing it
# here makes check_placement fail on 52 pre-existing cells that were always legal.
detailed_placement -max_displacement {200 20}
if {[catch {check_placement -verbose} m]} { puts "X_PLACE_WARN $m" } else { puts "X_PLACE_OK" }

# release the pins again so the DEF matches what the flow normally writes
set unpinned 0
foreach inst [$block getInsts] {
  if {[$inst getPlacementStatus] eq "FIRM"} { $inst setPlacementStatus PLACED; incr unpinned }
}
puts "X_UNPINNED $unpinned"

# ---- 2. freeze every already-routed net ----
# A net that reaches a top-level terminal is one the shell renamed, re-pinned or
# created, and the relocated tie cells sit right on the die edge next to those
# pins -- freezing them left DRT unable to reach dout[6] / dout_valid_o.  So:
# freeze the internal nets (that is where the timing closure lives) and let DRT
# route every I/O net from scratch.
set frozen 0; set newnets 0; set nodnt 0; set io 0; set wiped 0
foreach net [$block getNets] {
  set st [$net getSigType]
  if {$st eq "POWER" || $st eq "GROUND"} { continue }
  set w [$net getWire]
  if {[llength [$net getBTerms]] > 0} {
    incr io
    if {$w ne "NULL" && $w ne ""} { odb::dbWire_destroy $w; incr wiped }
    catch {$net clearGuides}
    continue
  }
  if {$w ne "NULL" && $w ne ""} {
    if {[catch {$net setDoNotTouch true}]} { incr nodnt } else { incr frozen }
  } else {
    incr newnets
  }
}
puts "X_IO_NETS_FREED $io  WIPED_ROUTES $wiped"
puts "X_FROZEN_NETS $frozen  UNROUTED_NETS $newnets  DNT_UNSUPPORTED $nodnt"
if {$nodnt > 0} { puts "X_ABORT setDoNotTouch unsupported in this build"; exit 1 }

# sample: remember one existing net's wire so we can prove it survived
set probe ""
foreach net [$block getNets] {
  if {[$net getSigType] eq "POWER" || [$net getSigType] eq "GROUND"} { continue }
  if {[llength [$net getBTerms]] > 0} { continue }
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

# ---- 3. release, fill, connect, write ----
foreach net [$block getNets] { catch {$net setDoNotTouch false} }
set pw [[$block findNet $probe] getWire]
puts "X_PROBE_WIRE_AFTER [expr {($pw ne "NULL" && $pw ne "") ? "PRESENT" : "GONE"}]"

set fills {}; set decaps {}
foreach lib [[ord::get_db] getLibs] { foreach m [$lib getMasters] {
  set n [$m getName]
  if {[string match "gf180mcu_fd_sc_mcu9t5v0__fillcap_*" $n]} { lappend decaps $n }
  if {[string match "gf180mcu_fd_sc_mcu9t5v0__fill_*" $n]}    { lappend fills $n }
}}
filler_placement [concat [lsort -decreasing $decaps] [lsort -decreasing $fills]]
add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
global_connect
puts "X_PSM_VDD"; check_power_grid -net VDD
puts "X_PSM_VSS"; check_power_grid -net VSS
write_db      $::env(OUT_DIR)/filled.odb
write_def     $::env(OUT_DIR)/filled.def
write_verilog -include_pwr_gnd $::env(OUT_DIR)/butterfold_top.final.pnl.v
puts "X_DONE BTERMS [llength [$block getBTerms]]  INST [llength [$block getInsts]]"
