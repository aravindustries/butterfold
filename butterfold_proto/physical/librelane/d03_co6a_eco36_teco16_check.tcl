# Verify teco16 nets are connected and WNS is real.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/setup_eco20
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $src/butterfold_top_co6a36_teco16.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set block [ord::get_db_block]
foreach nn {net265 _04335_} {
  set n [$block findNet $nn]
  if {$n eq "NULL"} { puts "MISSING_NET $nn"; continue }
  set w [$n getWire]
  set nterm [llength [$n getITerms]]
  puts "NET $nn terms=$nterm wire=$w"
  foreach it [$n getITerms] {
    puts "  TERM [[$it getInst] getName]/[[$it getMTerm] getName]"
  }
}
set inst [$block findInst rebuffer265]
puts "CELL rebuffer265 [[$inst getMaster] getName] [$inst getOrient]"
read_spef $src/after.max.spef
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
report_checks -path_delay max -slack_max 0 -group_path_count 10 \
  > $src/after_violations.rpt
report_checks -path_delay max -group_path_count 3 -fields {slew cap fanout net} \
  > $src/after_top3.rpt
set nine {_11280_ _11106_ _11366_ _11339_ _11136_ _11474_ _11394_ _11408_ _11241_}
set n_mx 0; set n_r180 0
foreach i [$block getInsts] {
  if {[[$i getMaster] getName] eq "gf180mcu_fd_sc_mcu9t5v0__aoi221_2"} {
    switch -- [$i getOrient] { MX {incr n_mx} R180 {incr n_r180} }
  }
}
puts "AOI221_2 MX $n_mx R180 $n_r180"
foreach name $nine {
  set i [$block findInst $name]
  puts "CELL $name [[$i getMaster] getName] [$i getOrient]"
}
puts "CHECK_DONE"
exit
