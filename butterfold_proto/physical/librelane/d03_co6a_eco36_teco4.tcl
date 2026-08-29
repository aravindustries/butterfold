# Targeted setup ECO4 from teco3.
# WNS is dft12_base[2] FO~142 (sibling of the FO~136 net we under-buffered).
# Split those two nets 8-way. Upsize the _18567_ *_1 chain and _18692_ tail.
# NO repair_design. Do not touch the nine aoi221_2 R180. Do not add aoi221_2.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/setup_eco7/butterfold_top_co6a36_teco3.odb
set outdir $proto/physical/results/d03_ach_candidate/co6a36/setup_eco8
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

proc eco_swap {block db inst tgt} {
  global nine
  if {$inst in $nine} { puts "SKIP_NINE $inst"; return 0 }
  set i [$block findInst $inst]
  if {$i eq "NULL" || $i eq ""} { puts "NOINST $inst"; return 0 }
  set src [[$i getMaster] getName]
  if {[string match *aoi221_2 $src]} { puts "SKIP_AOI221_2 $inst"; return 0 }
  set m [$db findMaster $tgt]
  if {$m eq "NULL" || $m eq ""} { puts "NOMASTER $tgt have=$src"; return 0 }
  if {$src eq $tgt} { puts "ALREADY $inst $tgt"; return 0 }
  if {[catch {$i swapMaster $m} msg]} {
    puts "SWAP_FAIL $inst $src -> $tgt $msg"
    return 0
  }
  puts "SWAP $inst $src -> $tgt"
  return 1
}

# 1-level split: original net keeps the driver and nleaves buffer inputs.
# Each leaf clkbuf drives a subset of the original loads.
proc split_net {block db netname nleaves master prefix} {
  set net [$block findNet $netname]
  if {$net eq "NULL" || $net eq ""} {
    puts "NONET $netname"
    return 0
  }
  set loads {}
  set drv {}
  foreach it [$net getITerms] {
    set iotype [$it getIoType]
    if {$iotype eq "OUTPUT"} {
      set drv $it
    } else {
      lappend loads $it
    }
  }
  set drvname none
  if {$drv ne ""} {
    set drvname "[[$drv getInst] getName]/[[$drv getMTerm] getName]"
  }
  puts "SPLIT $netname loads=[llength $loads] drv=$drvname"
  if {[llength $loads] < 12} { puts "SKIP_SMALL $netname"; return 0 }
  set m [$db findMaster $master]
  if {$m eq "NULL"} { return 0 }
  set x0 200000
  set y0 200000
  if {$drv ne ""} {
    lassign [[$drv getInst] getLocation] x0 y0
  }
  set leafnets {}
  for {set i 0} {$i < $nleaves} {incr i} {
    set buf [odb::dbInst_create $block $m ${prefix}_l$i]
    set bx [expr {$x0 + ($i % 4) * 28000}]
    set by [expr {$y0 + ($i / 4) * 20160}]
    $buf setOrient R0
    $buf setLocation $bx $by
    $buf setPlacementStatus PLACED
    set ln [odb::dbNet_create $block ${prefix}_n$i]
    odb::dbITerm_connect [$buf findITerm I] $net
    odb::dbITerm_connect [$buf findITerm Z] $ln
    lappend leafnets $ln
    puts "LEAF ${prefix}_l$i"
  }
  set idx 0
  foreach it $loads {
    set ln [lindex $leafnets [expr {$idx % $nleaves}]]
    odb::dbITerm_disconnect $it
    odb::dbITerm_connect $it $ln
    incr idx
  }
  puts "SPLIT_DONE $netname moved=$idx"
  return $nleaves
}

set nswap 0
# WNS path _18567_ dft12_base[2]
set pairs {
  _18567_ gf180mcu_fd_sc_mcu9t5v0__dffrnq_4
  _09100_ gf180mcu_fd_sc_mcu9t5v0__clkinv_8
  _12109_ gf180mcu_fd_sc_mcu9t5v0__aoi21_4
  _12112_ gf180mcu_fd_sc_mcu9t5v0__aoi221_4
  _12117_ gf180mcu_fd_sc_mcu9t5v0__nor2_4
  _12120_ gf180mcu_fd_sc_mcu9t5v0__aoi22_4
  _12164_ gf180mcu_fd_sc_mcu9t5v0__oai31_4
  _12165_ gf180mcu_fd_sc_mcu9t5v0__nand2_4
  _12195_ gf180mcu_fd_sc_mcu9t5v0__oai21_4
  _12211_ gf180mcu_fd_sc_mcu9t5v0__nand2_4
  _12237_ gf180mcu_fd_sc_mcu9t5v0__oai21_4
  _12251_ gf180mcu_fd_sc_mcu9t5v0__nand2_4
  _12271_ gf180mcu_fd_sc_mcu9t5v0__aoi21_4
  _12293_ gf180mcu_fd_sc_mcu9t5v0__oai21_4
  _12305_ gf180mcu_fd_sc_mcu9t5v0__aoi21_4
  _12329_ gf180mcu_fd_sc_mcu9t5v0__oai21_4
  _12339_ gf180mcu_fd_sc_mcu9t5v0__nand2_4
  _12350_ gf180mcu_fd_sc_mcu9t5v0__xnor2_4
  _12351_ gf180mcu_fd_sc_mcu9t5v0__aoi21_4
  _12352_ gf180mcu_fd_sc_mcu9t5v0__oai31_4
  _19139_ gf180mcu_fd_sc_mcu9t5v0__dffrnq_4
  _09513_ gf180mcu_fd_sc_mcu9t5v0__oai221_4
  _09511_ gf180mcu_fd_sc_mcu9t5v0__aoi21_4
  rebuffer271 gf180mcu_fd_sc_mcu9t5v0__clkbuf_16
  fanout300 gf180mcu_fd_sc_mcu9t5v0__clkbuf_8
  fanout257 gf180mcu_fd_sc_mcu9t5v0__clkbuf_8
  max_cap276 gf180mcu_fd_sc_mcu9t5v0__clkbuf_8
  max_cap279 gf180mcu_fd_sc_mcu9t5v0__clkbuf_8
  _16328_ gf180mcu_fd_sc_mcu9t5v0__mux2_4
}
foreach {inst tgt} $pairs {
  incr nswap [eco_swap $block $db $inst $tgt]
}

foreach inst {
  _18229_ _18231_ _18418_ _18230_ _18228_ _18226_ _18165_ _18161_
  _18167_ _18287_ _18354_ _18352_ _18168_ _18166_ _18355_ _18219_
  _18411_ _18413_
} {
  incr nswap [eco_swap $block $db $inst gf180mcu_fd_sc_mcu9t5v0__dffq_4]
}
puts "TECO4_SWAPPED $nswap"

set c16 gf180mcu_fd_sc_mcu9t5v0__clkbuf_16
set nleaf 0
incr nleaf [split_net $block $db {u_transform_scheduler_core.dft12_base[2]} 8 $c16 teco4_b2]
incr nleaf [split_net $block $db {u_transform_scheduler_core.dft12_base[3]} 8 $c16 teco4_b3]
incr nleaf [split_net $block $db {u_transform_scheduler_core.dft12_phase[0]} 4 $c16 teco4_p0]
puts "TECO4_LEAVES $nleaf"

catch {remove_fillers}
foreach inst [$block getInsts] {
  set mn [[$inst getMaster] getName]
  set n [$inst getName]
  if {$n in $nine || [string match *sram256x8m8wm1* $mn]} {
    $inst setPlacementStatus FIRM
  } else {
    $inst setPlacementStatus PLACED
  }
}
foreach name $nine { catch {set_dont_touch [get_cells $name]} }

set_placement_padding -global -left 2 -right 2
if {[catch {detailed_placement -max_displacement {400 120}} msg]} {
  puts "LEGALIZE_WARN $msg"
  catch {detailed_placement}
}
if {[catch {check_placement -verbose} cmsg]} { puts "PLACE_BAD $cmsg" } else { puts "PLACE_OK" }

foreach name $nine {
  set i [$block findInst $name]
  if {[[$i getMaster] getName] ne "gf180mcu_fd_sc_mcu9t5v0__aoi221_2" || [$i getOrient] ne "R180"} {
    puts "CELL_LOST $name [[$i getMaster] getName] [$i getOrient]"; exit 1
  }
  $i setPlacementStatus FIRM
}

puts "REROUTE_FULL_SIGNAL"
foreach net [$block getNets] {
  if {[$net isSpecial]} continue
  set st [$net getSigType]
  if {$st eq "POWER" || $st eq "GROUND"} continue
  set w [$net getWire]
  if {$w ne "" && $w ne "NULL"} { catch {odb::dbWire_destroy $w} }
  catch {$net clearGuides}
}
foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
catch {global_connect}
if {[catch {global_route -congestion_iterations 50 -verbose -guide_file $outdir/eco.guide} g]} {
  puts "GRT_FAIL $g"; exit 1
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
write_db $outdir/butterfold_top_co6a36_teco4.odb
write_def $outdir/butterfold_top_co6a36_teco4.def
puts "TECO4_DONE"
exit
