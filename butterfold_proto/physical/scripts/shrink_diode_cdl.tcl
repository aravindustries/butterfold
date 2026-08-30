set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set out $proto/physical/results/shrink_signoff
set pdk /foss/pdks/gf180mcuD
read_db $out/butterfold_top_closed.odb
set block [ord::get_db_block]
set diode 0
set sram 0
set mx2 0
foreach inst [$block getInsts] {
  set mn [[$inst getMaster] getName]
  if {[string match *antenna* $mn]} { incr diode }
  if {[string match *sram256x8m8wm1* $mn]} { incr sram }
  if {[string match *aoi221_2 $mn] && [$inst getOrient] eq "MX"} { incr mx2 }
}
puts "ANTENNA_DIODE_COUNT $diode SRAM $sram AOI221_2_MX $mx2"
write_cdl -include_fillers -masters "$pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/cdl/gf180mcu_fd_sc_mcu9t5v0.cdl $pdk/libs.ref/gf180mcu_fd_ip_sram/cdl/gf180mcu_fd_ip_sram__sram256x8m8wm1.cdl" $out/butterfold_top.cdl
puts CDL_DONE
