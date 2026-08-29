# Rip the two Metal1-shorted nets and re-DRT.
set eco /headless/aravindustries-repos/butterfold/butterfold_proto/physical/results/d03_ach_setup_eco
set pdk /foss/pdks/gf180mcuD
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_db $eco/butterfold_top_eco_routed.odb
set block [ord::get_db_block]
foreach nname {_02518_ _05678_} {
  set net [$block findNet $nname]
  if {$net eq "NULL" || $net eq ""} { puts "MISSING $nname"; continue }
  if {[$net getWire] ne "" && [$net getWire] ne "NULL"} {
    odb::dbWire_destroy [$net getWire]
    puts "RIPPED $nname"
  }
  $net clearGuides
}
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
foreach layer {Metal2 Metal3 Metal4 Metal5} {
  set_global_routing_layer_adjustment $layer 0.3
}
global_route -congestion_iterations 20 -verbose
detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 \
  -output_drc $eco/eco_shortfix.drc
write_db $eco/butterfold_top_eco_routed.odb
write_def $eco/butterfold_top_eco_routed.def
puts "SHORTFIX_DONE"
exit
