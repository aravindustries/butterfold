set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_setup_eco
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $eco/butterfold_top_eco18i.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
read_spef $eco/eco18i.max.spef
puts "WNS"; report_wns -max
puts "TNS"; report_tns -max
puts "PATH_18433"
if {[catch {report_checks -from _18692_ -to _18433_ -path_delay max} e1]} { puts "RPT $e1" }
puts "PATH_SRAM_LO"
if {[catch {report_checks -to u_transform_scheduler_core.u_fft_scratch_sram.u_lo.u_sram -path_delay max -group_path_count 2} e2]} { puts "RPT $e2" }
set block [ord::get_db_block]
set n [$block findNet eco18_net_18433]
puts "NET eco18_net_18433 wire=[$n getWire] terms=[llength [$n getITerms]]"
foreach it [$n getITerms] { puts "  [[$it getInst] getName]/[[$it getMTerm] getName]" }
set buf [$block findInst eco18_sk_18433]
puts "BUF [[$buf getMaster] getName] status=[$buf getPlacementStatus]"
lassign [$buf getLocation] x y
puts "BUF_LOC $x $y"
if {[catch {check_placement -verbose} m]} { puts "PLACE $m" } else { puts "PLACE_OK" }
# sram count
set nsram 0
foreach inst [$block getInsts] {
  if {[string match "*sram256x8*" [[$inst getMaster] getName]]} { incr nsram; puts "SRAM [$inst getName]" }
}
puts "NSRAM $nsram"
report_check_types -max_slew -max_cap -max_fanout -violators
exit
