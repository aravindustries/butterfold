# teco20 from teco18: KEEP_WIRES *_1 -> *_2 on 23 cap/slew drivers that fit to the right.
# No new cells, no capture clock, no full reroute. Recheck setup after extract.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/setup_eco22/butterfold_top_co6a36_teco18.odb
set outdir $proto/physical/results/d03_ach_candidate/co6a36/setup_eco24
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
set swaps {
  _09877_ gf180mcu_fd_sc_mcu9t5v0__nor2_2
  _09422_ gf180mcu_fd_sc_mcu9t5v0__nor2_2
  _10216_ gf180mcu_fd_sc_mcu9t5v0__nor2_2
  _11083_ gf180mcu_fd_sc_mcu9t5v0__nand2_2
  _15865_ gf180mcu_fd_sc_mcu9t5v0__nor2_2
  _10224_ gf180mcu_fd_sc_mcu9t5v0__nand2_2
  clone309 gf180mcu_fd_sc_mcu9t5v0__nor2_2
  clone396 gf180mcu_fd_sc_mcu9t5v0__nor2_2
  _09901_ gf180mcu_fd_sc_mcu9t5v0__nor2_2
  _09889_ gf180mcu_fd_sc_mcu9t5v0__nor3_2
  _09907_ gf180mcu_fd_sc_mcu9t5v0__nor2_2
  _09911_ gf180mcu_fd_sc_mcu9t5v0__nor2_2
  _11120_ gf180mcu_fd_sc_mcu9t5v0__oai31_2
  _10243_ gf180mcu_fd_sc_mcu9t5v0__nor2_2
  _11325_ gf180mcu_fd_sc_mcu9t5v0__nand2_2
  _09910_ gf180mcu_fd_sc_mcu9t5v0__nor2_2
  _09912_ gf180mcu_fd_sc_mcu9t5v0__nor2_2
  _11075_ gf180mcu_fd_sc_mcu9t5v0__nand2_2
  _09657_ gf180mcu_fd_sc_mcu9t5v0__nand2_2
  _09895_ gf180mcu_fd_sc_mcu9t5v0__nor2_2
  _12227_ gf180mcu_fd_sc_mcu9t5v0__xnor2_2
  _09471_ gf180mcu_fd_sc_mcu9t5v0__nor2_2
  _12450_ gf180mcu_fd_sc_mcu9t5v0__oai32_2
}
set nswap 0
foreach {name tgt} $swaps {
  set i [$block findInst $name]
  set m [$db findMaster $tgt]
  set ori [$i getOrient]
  lassign [$i getLocation] x y
  if {[catch {$i swapMaster $m} msg]} { puts "FAIL $name $msg"; continue }
  $i setOrient $ori
  $i setLocation $x $y
  $i setPlacementStatus FIRM
  incr nswap
  puts "SWAP $name $tgt"
}
puts "NSWAP $nswap"
foreach name $nine {
  set i [$block findInst $name]
  if {[[$i getMaster] getName] ne "gf180mcu_fd_sc_mcu9t5v0__aoi221_2" || [$i getOrient] ne "R180"} {
    puts "CELL_LOST $name [[$i getMaster] getName] [$i getOrient]"; exit 1
  }
}
puts "KEEP_WIRES EXTRACT"
extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
write_spef $outdir/after.max.spef
read_spef $outdir/after.max.spef
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
puts "SLEW [sta::max_slew_violation_count]"
puts "CAP [sta::max_capacitance_violation_count]"
report_wns -max > $outdir/setup_wns.rpt
report_tns -max > $outdir/setup_tns.rpt
report_checks -path_delay max -group_path_count 3 > $outdir/setup_top3.rpt
report_check_types -max_slew -max_cap -violators > $outdir/elec_liberty_violators.rpt
set n_mx 0; set n_r180 0
foreach i [$block getInsts] {
  if {[[$i getMaster] getName] eq "gf180mcu_fd_sc_mcu9t5v0__aoi221_2"} {
    switch -- [$i getOrient] { MX {incr n_mx} R180 {incr n_r180} }
  }
}
puts "AOI221_2 MX $n_mx R180 $n_r180"
write_db $outdir/butterfold_top_co6a36_teco20.odb
puts "TECO20_DONE"
exit
