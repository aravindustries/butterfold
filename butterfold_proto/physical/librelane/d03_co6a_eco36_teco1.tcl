# Targeted setup ECO1 from the best R180 setup2 checkpoint.
# Path class: ALL top-80 extracted max-SS violators start at _18564_
# (dft12_phase[0]). Shared weak prefix + hold-delay cells on the data cone.
# NO repair_design. NO global buffering. Do not touch the nine aoi221_2 R180.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/setup_eco2/butterfold_top_co6a36_setup2.odb
set outdir $proto/physical/results/d03_ach_candidate/co6a36/setup_eco5
file mkdir $outdir
puts "ECO_SRC $src"

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $src
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_dont_use {gf180mcu_fd_sc_mcu9t5v0__bufz_* gf180mcu_fd_sc_mcu9t5v0__antenna gf180mcu_fd_sc_mcu9t5v0__hold gf180mcu_fd_sc_mcu9t5v0__dlya_* gf180mcu_fd_sc_mcu9t5v0__dlyb_*}
set_max_transition 3 [current_design]
set_max_capacitance 0.2 [current_design]
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
catch {set_thread_count 22}

set nine {_11280_ _11106_ _11366_ _11339_ _11136_ _11474_ _11394_ _11408_ _11241_}
set db [ord::get_db]
set block [ord::get_db_block]

proc is_phys {inst} {
  set mn [[$inst getMaster] getName]
  if {[string match *sram256x8m8wm1* $mn]} { return 1 }
  if {[string match *fill* $mn]} { return 1 }
  if {[string match *endcap* $mn]} { return 1 }
  if {[string match *tap* $mn]} { return 1 }
  if {[string match *decap* $mn]} { return 1 }
  return 0
}
proc is_protected {inst nine} {
  set n [$inst getName]
  if {$n in $nine} { return 1 }
  return [is_phys $inst]
}

foreach name $nine {
  set i [$block findInst $name]
  $i setPlacementStatus FIRM
  catch {set_dont_touch [get_cells $name]}
}
foreach inst [$block getInsts] {
  if {[is_protected $inst $nine]} { $inst setPlacementStatus FIRM }
}

proc eco_swap {block db inst tgt} {
  global nine
  if {$inst in $nine} { puts "SKIP_NINE $inst"; return 0 }
  set i [$block findInst $inst]
  if {$i eq "NULL" || $i eq ""} { puts "NOINST $inst"; return 0 }
  set src [[$i getMaster] getName]
  set m [$db findMaster $tgt]
  if {$m eq "NULL" || $m eq ""} { puts "NOMASTER $tgt"; return 0 }
  if {$src eq $tgt} { puts "ALREADY $inst $tgt"; return 0 }
  if {[catch {$i swapMaster $m} msg]} {
    puts "SWAP_FAIL $inst $src -> $tgt $msg"
    return 0
  }
  puts "SWAP $inst $src -> $tgt"
  return 1
}

set nswap 0

# Hold-delay cells sitting on the setup-critical cone (~2.1-2.5 ns each).
foreach inst {fanout300 fanout301 clone310 fanout294} {
  incr nswap [eco_swap $block $db $inst gf180mcu_fd_sc_mcu9t5v0__clkbuf_4]
}
incr nswap [eco_swap $block $db clone399 gf180mcu_fd_sc_mcu9t5v0__clkbuf_4]

# Shared prefix on all 80 worst paths.
incr nswap [eco_swap $block $db _09419_ gf180mcu_fd_sc_mcu9t5v0__nand2_4]
incr nswap [eco_swap $block $db _09512_ gf180mcu_fd_sc_mcu9t5v0__nand2_4]
incr nswap [eco_swap $block $db _09513_ gf180mcu_fd_sc_mcu9t5v0__oai221_2]
incr nswap [eco_swap $block $db _09424_ gf180mcu_fd_sc_mcu9t5v0__aoi21_4]
incr nswap [eco_swap $block $db _09514_ gf180mcu_fd_sc_mcu9t5v0__or2_4]
incr nswap [eco_swap $block $db _18564_ gf180mcu_fd_sc_mcu9t5v0__dffrnq_4]
incr nswap [eco_swap $block $db max_cap217 gf180mcu_fd_sc_mcu9t5v0__clkbuf_8]

# High-impact branch cells.
incr nswap [eco_swap $block $db _15953_ gf180mcu_fd_sc_mcu9t5v0__aoi211_2]
incr nswap [eco_swap $block $db _15978_ gf180mcu_fd_sc_mcu9t5v0__nand2_4]
incr nswap [eco_swap $block $db clone308 gf180mcu_fd_sc_mcu9t5v0__nor2_4]
incr nswap [eco_swap $block $db _16440_ gf180mcu_fd_sc_mcu9t5v0__aoi21_4]
incr nswap [eco_swap $block $db _15981_ gf180mcu_fd_sc_mcu9t5v0__nor3_4]
puts "TECO1_SWAPPED $nswap"

set swapped {
  fanout300 fanout301 clone310 fanout294 clone399
  _09419_ _09512_ _09513_ _09424_ _09514_ _18564_ max_cap217
  _15953_ _15978_ clone308 _16440_ _15981_
}

# FIRM the whole design, then un-FIRM swapped cells + a local window so
# legalize can make room without sliding the R180 nine / SRAM / CTS.
foreach inst [$block getInsts] { $inst setPlacementStatus FIRM }
set swapped_insts {}
foreach name $swapped {
  set i [$block findInst $name]
  if {$i eq "NULL" || $i eq ""} { continue }
  lappend swapped_insts $i
  $i setPlacementStatus PLACED
}

set_placement_padding -global -left 2 -right 2
if {[catch {detailed_placement -incremental -max_displacement {80 40}} msg]} {
  puts "LEGALIZE_WARN $msg"
  # Make room: un-FIRM nearby logic only, never TAP/fill/endcap/SRAM/nine.
  set win 40000
  foreach si $swapped_insts {
    lassign [$si getLocation] fx fy
    foreach inst [$block getInsts] {
      if {[is_protected $inst $nine]} { continue }
      set iname [$inst getName]
      if {[string match clkbuf_* $iname] || [string match *core_clk* $iname]} { continue }
      lassign [$inst getLocation] ix iy
      if {abs($ix - $fx) < $win && abs($iy - $fy) < $win} {
        $inst setPlacementStatus PLACED
      }
    }
  }
  if {[catch {detailed_placement -incremental -max_displacement {200 80}} msg2]} {
    puts "LEGALIZE2_WARN $msg2"
  }
}
if {[catch {check_placement -verbose} cmsg]} { puts "PLACE_BAD $cmsg" } else { puts "PLACE_OK" }

foreach name $nine {
  set i [$block findInst $name]
  if {[[$i getMaster] getName] ne "gf180mcu_fd_sc_mcu9t5v0__aoi221_2" || [$i getOrient] ne "R180"} {
    puts "CELL_LOST $name [[$i getMaster] getName] [$i getOrient]"; exit 1
  }
  $i setPlacementStatus FIRM
}

# Route only nets of swapped cells. Keep all other wires.
array set changed {}
foreach name $swapped {
  set i [$block findInst $name]
  if {$i eq "NULL" || $i eq ""} { continue }
  foreach it [$i getITerms] {
    set n [$it getNet]
    if {$n eq "NULL" || $n eq ""} { continue }
    if {[$n isSpecial]} { continue }
    set st [$n getSigType]
    if {$st eq "POWER" || $st eq "GROUND" || $st eq "CLOCK"} { continue }
    set nn [$n getName]
    if {[string match *clk* [string tolower $nn]]} { continue }
    set changed($nn) $n
  }
}
set nrip 0
foreach nn [array names changed] {
  set n $changed($nn)
  set w [$n getWire]
  if {$w ne "" && $w ne "NULL"} {
    catch {odb::dbWire_destroy $w}
    incr nrip
  }
  catch {$n clearGuides}
}
puts "RIP_CHANGED_NETS $nrip"

foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
catch {global_connect}
if {[catch {global_route -congestion_iterations 30 -verbose -guide_file $outdir/eco.guide} g]} {
  puts "GRT_WARN $g"
} else { puts "GRT_OK" }
if {[catch {detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $outdir/eco.drc} d]} {
  puts "DRT_WARN $d"
} else { puts "DRT_OK" }

puts "EXTRACT"
extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
write_spef $outdir/after.max.spef
read_spef $outdir/after.max.spef
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
puts "HOLD_WNS_MAXCORNER"; report_wns -min
puts "HOLD_TNS_MAXCORNER"; report_tns -min
catch {puts "SLEW [sta::max_slew_violation_count]"}
catch {puts "CAP [sta::max_capacitance_violation_count]"}
report_wns -max > $outdir/setup_wns.rpt
report_tns -max > $outdir/setup_tns.rpt
report_checks -path_delay max -group_path_count 15 -fields {slew cap fanout net} \
  > $outdir/setup_top15.rpt

set n_mx 0; set n_r180 0; set n_r0 0; set n_my 0
foreach inst [$block getInsts] {
  if {[[$inst getMaster] getName] eq "gf180mcu_fd_sc_mcu9t5v0__aoi221_2"} {
    switch -- [$inst getOrient] { MX {incr n_mx} R180 {incr n_r180} R0 {incr n_r0} MY {incr n_my} }
  }
}
puts "AOI221_2 MX $n_mx R180 $n_r180 R0 $n_r0 MY $n_my"
foreach name $nine {
  set i [$block findInst $name]
  puts "CELL $name [[$i getMaster] getName] [$i getOrient]"
}

write_db $outdir/butterfold_top_co6a36_teco1.odb
write_def $outdir/butterfold_top_co6a36_teco1.def
puts "TECO1_DONE"
exit
