# Targeted setup ECO5 from teco4. Remaining class is _18692_ (WNS -2.50).
# Tail *_1/*_2 + buffers after slow max-size gates + skip_buffering resize.
# NO repair_design. Do not touch the nine aoi221_2 R180.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/setup_eco8/butterfold_top_co6a36_teco4.odb
set outdir $proto/physical/results/d03_ach_candidate/co6a36/setup_eco9
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
proc eco_insert_buf {block db instname pin mastername bufname} {
  set inst [$block findInst $instname]
  if {$inst eq "NULL" || $inst eq ""} { puts "NOINST_BUF $instname"; return 0 }
  if {[$block findInst $bufname] ne "NULL" && [$block findInst $bufname] ne ""} {
    puts "BUF_EXISTS $bufname"; return 0
  }
  set iterm [$inst findITerm $pin]
  if {$iterm eq "NULL" || $iterm eq ""} { return 0 }
  set oldnet [$iterm getNet]
  if {$oldnet eq "NULL" || $oldnet eq ""} { return 0 }
  set master [$db findMaster $mastername]
  if {$master eq "NULL"} { return 0 }
  set mid [odb::dbNet_create $block ${bufname}_i]
  set buf [odb::dbInst_create $block $master $bufname]
  lassign [$inst getLocation] x y
  $buf setOrient R0
  $buf setLocation [expr {$x + 2240}] $y
  $buf setPlacementStatus PLACED
  odb::dbITerm_disconnect $iterm
  odb::dbITerm_connect $iterm $mid
  odb::dbITerm_connect [$buf findITerm I] $mid
  odb::dbITerm_connect [$buf findITerm Z] $oldnet
  puts "INSERTED $bufname after $instname/$pin"
  return 1
}

set nswap 0
set pairs {
  _15980_ gf180mcu_fd_sc_mcu9t5v0__nand3_4
  load_slew94 gf180mcu_fd_sc_mcu9t5v0__clkbuf_16
  _09504_ gf180mcu_fd_sc_mcu9t5v0__oai222_4
  _09503_ gf180mcu_fd_sc_mcu9t5v0__aoi21_4
  _15991_ gf180mcu_fd_sc_mcu9t5v0__oai32_4
  _15996_ gf180mcu_fd_sc_mcu9t5v0__aoi21_4
  fanout238 gf180mcu_fd_sc_mcu9t5v0__clkbuf_8
  load_slew281 gf180mcu_fd_sc_mcu9t5v0__clkbuf_16
  _16097_ gf180mcu_fd_sc_mcu9t5v0__mux2_4
  _16061_ gf180mcu_fd_sc_mcu9t5v0__mux2_4
  _16085_ gf180mcu_fd_sc_mcu9t5v0__mux2_4
  _16637_ gf180mcu_fd_sc_mcu9t5v0__mux2_4
  _16625_ gf180mcu_fd_sc_mcu9t5v0__mux2_4
  _16103_ gf180mcu_fd_sc_mcu9t5v0__mux2_4
  _16091_ gf180mcu_fd_sc_mcu9t5v0__mux2_4
  _16457_ gf180mcu_fd_sc_mcu9t5v0__mux2_4
  _16458_ gf180mcu_fd_sc_mcu9t5v0__mux2_4
  _16643_ gf180mcu_fd_sc_mcu9t5v0__mux2_4
  _16445_ gf180mcu_fd_sc_mcu9t5v0__mux2_4
  _16446_ gf180mcu_fd_sc_mcu9t5v0__mux2_4
  _16981_ gf180mcu_fd_sc_mcu9t5v0__mux2_4
  _16193_ gf180mcu_fd_sc_mcu9t5v0__oai31_4
  _16195_ gf180mcu_fd_sc_mcu9t5v0__oai31_4
  _18184_ gf180mcu_fd_sc_mcu9t5v0__dffq_4
  _18281_ gf180mcu_fd_sc_mcu9t5v0__dffq_4
  _18482_ gf180mcu_fd_sc_mcu9t5v0__dffq_4
  _18164_ gf180mcu_fd_sc_mcu9t5v0__dffq_4
  _18285_ gf180mcu_fd_sc_mcu9t5v0__dffq_4
  _18475_ gf180mcu_fd_sc_mcu9t5v0__dffq_4
}
foreach {inst tgt} $pairs {
  incr nswap [eco_swap $block $db $inst $tgt]
}
set c16 gf180mcu_fd_sc_mcu9t5v0__clkbuf_16
set nbuf 0
incr nbuf [eco_insert_buf $block $db _15937_ ZN $c16 teco5_buf_15937]
incr nbuf [eco_insert_buf $block $db _15992_ ZN $c16 teco5_buf_15992]
incr nbuf [eco_insert_buf $block $db _09435_ ZN $c16 teco5_buf_09435]
incr nbuf [eco_insert_buf $block $db _09472_ ZN $c16 teco5_buf_09472]
puts "TECO5_SWAPPED $nswap BUF $nbuf"

foreach name $nine {
  set i [$block findInst $name]
  $i setPlacementStatus FIRM
  catch {set_dont_touch [get_cells $name]}
}
foreach inst [$block getInsts] {
  set mn [[$inst getMaster] getName]
  if {[string match *sram256x8m8wm1* $mn]} {
    $inst setPlacementStatus FIRM
    catch {set_dont_touch [get_cells [$inst getName]]}
  }
}
foreach pat {clkbuf_*core_clk* clkbuf_*clk_regs* clkbuf_leaf_*} {
  catch {set_dont_touch [get_cells -quiet $pat]}
}

puts "SKIP_BUFFERING_RESIZE"
estimate_parasitics -placement
if {[catch {repair_timing -setup -skip_buffering -repair_tns 100 -setup_margin 0.3} m]} {
  puts "REPAIR_TIMING_WARN $m"
}
estimate_parasitics -placement
puts "AFTER_SKIP_BUFFERING"
report_wns -max
report_tns -max

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
report_checks -path_delay max -group_path_count 12 -fields {slew cap fanout net} \
  > $outdir/setup_top12.rpt

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
write_db $outdir/butterfold_top_co6a36_teco5.odb
write_def $outdir/butterfold_top_co6a36_teco5.def
puts "TECO5_DONE"
exit
