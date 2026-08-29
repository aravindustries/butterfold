set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_setup_eco
set out $proto/physical/reports/signoff/evidence/d03_ach/setup
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $eco/butterfold_top_eco18c.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
read_spef $eco/eco18c.max.spef
puts "WNS"; report_wns -max
puts "TNS"; report_tns -max
puts "WORST_PATHS"
report_checks -path_delay max -group_path_count 5
set block [ord::get_db_block]
set ff [$block findInst _18433_]
set clk [$ff findITerm CLK]
set n [$clk getNet]
puts "18433_CLK_NET [$n getName] wire=[$n getWire] terms=[llength [$n getITerms]]"
set buf [$block findInst eco18_sk_18433]
puts "BUF status=[$buf getPlacementStatus] master=[[$buf getMaster] getName]"
lassign [$buf getLocation] x y
puts "BUF loc $x $y"
if {[catch {check_placement -verbose} m]} { puts "PLACE $m" } else { puts "PLACE_OK" }
exit
