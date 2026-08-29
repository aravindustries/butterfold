# From best teco12 (WNS -0.09). Insert last capture clkbuf_16s.
# Keep existing wires. Incremental GRT/DRT only.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/setup_eco16/butterfold_top_co6a36_teco12.odb
set outdir $proto/physical/results/d03_ach_candidate/co6a36/setup_eco18
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
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
catch {set_thread_count 22}

set nine {_11280_ _11106_ _11366_ _11339_ _11136_ _11474_ _11394_ _11408_ _11241_}
set db [ord::get_db]
set block [ord::get_db_block]
set c16 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__clkbuf_16]

# FIRM the whole design first so legalize only moves new bufs.
foreach inst [$block getInsts] { $inst setPlacementStatus FIRM }

proc insert_clk_skew {block db instname pin master bufname} {
  set inst [$block findInst $instname]
  if {$inst eq "NULL" || $inst eq ""} { puts "NOINST $instname"; return 0 }
  if {[$block findInst $bufname] ne "NULL" && [$block findInst $bufname] ne ""} { return 0 }
  catch {unset_dont_touch [get_cells $instname]}
  set iterm [$inst findITerm $pin]
  if {$iterm eq "NULL"} { return 0 }
  set old [$iterm getNet]
  if {$old eq "NULL"} { return 0 }
  set buf [odb::dbInst_create $block $master $bufname]
  lassign [$inst getLocation] x y
  $buf setOrient R0
  $buf setLocation [expr {$x + 2240}] [expr {$y + 5040}]
  $buf setPlacementStatus PLACED
  set n2 [odb::dbNet_create $block ${bufname}_n]
  odb::dbITerm_connect [$buf findITerm I] $old
  odb::dbITerm_connect [$buf findITerm Z] $n2
  odb::dbITerm_disconnect $iterm
  odb::dbITerm_connect $iterm $n2
  puts "SKEW $bufname on $instname"
  return 1
}

set nsk 0
incr nsk [insert_clk_skew $block $db u_transform_scheduler_core.u_fft_scratch_sram.u_lo.u_sram CLK $c16 teco14_sk_lo]
incr nsk [insert_clk_skew $block $db u_transform_scheduler_core.u_fft_scratch_sram.u_hi.u_sram CLK $c16 teco14_sk_hi]
foreach ff {_18287_ _18480_ _18288_ _18479_} {
  incr nsk [insert_clk_skew $block $db $ff CLK $c16 teco14_sk_$ff]
}
puts "TECO14_SKEW $nsk"

set_placement_padding -global -left 2 -right 2
if {[catch {detailed_placement -incremental -max_displacement {80 40}} msg]} {
  puts "LEGALIZE_WARN $msg"
  # un-FIRM a small window around new bufs
  foreach inst [$block getInsts] {
    set n [$inst getName]
    if {[string match teco14_sk_* $n]} { $inst setPlacementStatus PLACED }
  }
  catch {detailed_placement -incremental -max_displacement {200 80}}
}
foreach name $nine {
  set i [$block findInst $name]
  if {[[$i getMaster] getName] ne "gf180mcu_fd_sc_mcu9t5v0__aoi221_2" || [$i getOrient] ne "R180"} {
    puts "CELL_LOST $name [[$i getMaster] getName] [$i getOrient]"; exit 1
  }
  $i setPlacementStatus FIRM
}

puts "INCREMENTAL_ROUTE"
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
report_checks -path_delay max -group_path_count 6 > $outdir/setup_top6.rpt
set n_mx 0; set n_r180 0; set n_r0 0; set n_my 0
foreach inst [$block getInsts] {
  if {[[$inst getMaster] getName] eq "gf180mcu_fd_sc_mcu9t5v0__aoi221_2"} {
    switch -- [$inst getOrient] { MX {incr n_mx} R180 {incr n_r180} R0 {incr n_r0} MY {incr n_my} }
  }
}
puts "AOI221_2 MX $n_mx R180 $n_r180 R0 $n_r0 MY $n_my"
write_db $outdir/butterfold_top_co6a36_teco14.odb
write_def $outdir/butterfold_top_co6a36_teco14.def
puts "TECO14_DONE"
exit
