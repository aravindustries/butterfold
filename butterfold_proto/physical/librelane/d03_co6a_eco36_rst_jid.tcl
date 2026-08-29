set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_db $proto/physical/results/d03_ach_candidate/co6a36/setup_eco25/butterfold_top_co6a36_teco21.odb
set block [ord::get_db_block]
set tech [ord::get_db_tech]
set m2 [$tech findLayer Metal2]
set m3 [$tech findLayer Metal3]
set net [odb::dbNet_create $block jidtest]
set w [odb::dbWire_create $net]
set e [odb::dbWireEncoder]
$e begin $w
$e newPath $m3 ROUTED
set j1 [$e addPoint 10000 20000]
puts "J1 $j1"
set j2 [$e addPoint 50000 20000]
puts "J2 $j2"
if {[catch {$e newPath $j2 ROUTED} msg]} { puts "NPJ $msg" } else { puts "NPJ_OK" }
# after newPath(int) the layer may stay M3; try addPoint then via? just addPoint
if {[catch {$e addPoint 50000 40000} msg]} { puts "P3 $msg" } else { puts "P3_OK" }
$e end
puts "LEN [$w getLength]"
# paths
set pitr [odb::dbWirePathItr]
set path [odb::dbWirePath]
set shape [odb::dbWirePathShape]
$pitr begin $w
set np 0
while {[$pitr getNextPath $path]} {
  incr np
  set ns 0
  while {[$pitr getNextShape $shape]} { incr ns }
  puts "PATH $np shapes $ns"
}
puts "NP $np"
exit

