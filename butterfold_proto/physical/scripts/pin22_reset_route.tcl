# Insert regional rst_n tree then GRT+DRT for pin-redesign-22 compact die.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/pin22_signoff
set pdk /foss/pdks/gf180mcuD
set sdc $proto/physical/constraints.sdc
# Pre-filler post-DRT checkpoint (same stage as historical compact ECO).
set src $proto/physical/librelane/runs/pin22_9t/44-odb-reportdisconnectedpins/butterfold_top.odb
file mkdir $out
file mkdir $out/drt

proc diode_count {} {
  set n 0
  foreach inst [[ord::get_db_block] getInsts] {
    if {[string match "*__antenna" [[$inst getMaster] getName]]} { incr n }
  }
  return $n
}
proc destroy_signal_wires {} {
  foreach net [[ord::get_db_block] getNets] {
    set st [$net getSigType]
    if {$st eq "POWER" || $st eq "GROUND"} { continue }
    set w [$net getWire]
    if {$w ne "NULL" && $w ne ""} { catch {odb::dbWire_destroy $w} }
    catch {$net clearGuides}
  }
}
proc pg_connect {} {
  add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
  add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
  add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
  add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
  global_connect
}
proc legalize {} {
  catch {remove_fillers}
  set_placement_padding -global -left 1 -right 1
  foreach wildcard {gf180mcu_fd_sc_mcu9t5v0__filltie gf180mcu_fd_sc_mcu9t5v0__fill_* gf180mcu_fd_sc_mcu9t5v0__endcap} {
    catch {set_placement_padding -masters $wildcard -right 0 -left 0}
  }
  if {[catch {detailed_placement -max_displacement {500 100}}]} {
    puts "PLACE_RETRY"
    detailed_placement -max_displacement {2000 400}
  }
  if {[catch {check_placement -verbose} cmsg]} { puts "PLACE_FAIL $cmsg"; exit 1 }
}

set c max_ss_125C_4v50
define_corners $c
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $src
read_sdc $sdc
catch {unset_case_analysis rst_n}
catch {unset_case_analysis [get_ports rst_n]}

set db [ord::get_db]
set block [ord::get_db_block]
set tech [$db getTech]
set dbu [$tech getDbUnitsPerMicron]
set m16 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__clkbuf_16]
set m8 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__clkbuf_8]
if {$m16 eq "NULL" || $m8 eq "NULL"} { error "missing clkbuf master" }

set rst [$block findNet rst_n]
set loads {}
foreach it [$rst getITerms] {
  set inst [$it getInst]
  if {$inst eq "NULL"} { continue }
  set pin [[$it getMTerm] getName]
  if {$pin eq "Z" || $pin eq "ZN"} { continue }
  lappend loads $it
}
puts "RST_LOADS [llength $loads]"

set core [$block getCoreArea]
set x0 [$core xMin]; set y0 [$core yMin]; set x1 [$core xMax]; set y1 [$core yMax]
set nx 4; set ny 3
set dx [expr {($x1-$x0)/double($nx)}]
set dy [expr {($y1-$y0)/double($ny)}]
proc bin_xy {x y} {
  upvar x0 x0 y0 y0 dx dx dy dy nx nx ny ny
  set bx [expr {int(($x-$x0)/$dx)}]
  set by [expr {int(($y-$y0)/$dy)}]
  if {$bx < 0} { set bx 0 }
  if {$by < 0} { set by 0 }
  if {$bx >= $nx} { set bx [expr {$nx-1}] }
  if {$by >= $ny} { set by [expr {$ny-1}] }
  return [expr {$by*$nx + $bx}]
}
set nreg [expr {$nx*$ny}]
for {set i 0} {$i < $nreg} {incr i} { set buckets($i) {} }
foreach it $loads {
  set inst [$it getInst]
  set loc [$inst getLocation]
  set b [bin_xy [lindex $loc 0] [lindex $loc 1]]
  lappend buckets($b) $it
}

set rst_int [odb::dbNet_create $block rst_n_int]
set root [odb::dbInst_create $block $m16 rst_root]
$root setOrient R0
$root setLocation [expr {int(20.16*$dbu)}] [expr {int(1070*$dbu)}]
$root setPlacementStatus PLACED
[$root findITerm I] connect $rst
[$root findITerm Z] connect $rst_int

for {set i 0} {$i < $nreg} {incr i} {
  set net [odb::dbNet_create $block rst_n_r$i]
  set inst [odb::dbInst_create $block $m8 rst_reg$i]
  set bx [expr {$i % $nx}]
  set by [expr {$i / $nx}]
  set px [expr {int($x0 + (0.5+$bx)*$dx)}]
  set py [expr {int($y0 + (0.5+$by)*$dy)}]
  $inst setOrient R0
  $inst setLocation $px $py
  $inst setPlacementStatus PLACED
  [$inst findITerm I] connect $rst_int
  [$inst findITerm Z] connect $net
  puts "RST_REGION $i loads [llength $buckets($i)] at [expr {$px/double($dbu)}] [expr {$py/double($dbu)}]"
  foreach it $buckets($i) {
    $it disconnect
    $it connect $net
  }
}
pg_connect
legalize
write_db $out/reset_eco.odb
puts "WROTE_RESET"

set_thread_count 16
destroy_signal_wires
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
foreach layer {Metal2 Metal3 Metal4 Metal5} {
  set_global_routing_layer_adjustment $layer 0.3
}
puts "GRT"
global_route -congestion_iterations 50 -verbose
puts "GRT_DONE"
repair_antennas gf180mcu_fd_sc_mcu9t5v0__antenna -iterations 3 -ratio_margin 10
catch {detailed_placement -max_displacement {500 100}}
puts "DRT DIODE [diode_count]"
detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $out/drt/reset.drc
puts "DRT_DONE"
check_antennas
write_db $out/routed.odb
write_def $out/routed.def
puts "WROTE_ROUTED DIODE [diode_count]"
exit 0
