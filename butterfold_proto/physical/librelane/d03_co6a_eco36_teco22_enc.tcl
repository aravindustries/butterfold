set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_db $proto/physical/results/d03_ach_candidate/co6a36/setup_eco25/butterfold_top_co6a36_teco21.odb
set block [ord::get_db_block]
set tech [ord::get_db_tech]
set m2 [$tech findLayer Metal2]
set net [odb::dbNet_create $block teco22_dummy]
set w [odb::dbWire_create $net]
set enc [odb::dbWireEncoder]
$enc begin $w
foreach try {
  {$enc newPath $m2 ROUTED}
  {$enc newPath $m2 1}
  {$enc newPath $m2}
} {
  if {[catch {eval $try} msg]} { puts "FAIL $try $msg" } else { puts "OK $try"; break }
}
exit
