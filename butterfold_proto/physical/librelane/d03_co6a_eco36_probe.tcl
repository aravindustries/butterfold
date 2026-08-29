# Probe pad4 pre-DRT checkpoint.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set odb $proto/physical/librelane/runs/d03_ach_pnr_pad4/10-openroad-resizertimingpostgrt/butterfold_top.odb
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $odb
set block [ord::get_db_block]
set dbu [$block getDefUnits]
set die [$block getDieArea]
set core [$block getCoreArea]
puts [format "DIE %.3f %.3f %.3f %.3f" [expr {[$die xMin]*1.0/$dbu}] [expr {[$die yMin]*1.0/$dbu}] [expr {[$die xMax]*1.0/$dbu}] [expr {[$die yMax]*1.0/$dbu}]]
puts [format "CORE %.3f %.3f %.3f %.3f" [expr {[$core xMin]*1.0/$dbu}] [expr {[$core yMin]*1.0/$dbu}] [expr {[$core xMax]*1.0/$dbu}] [expr {[$core yMax]*1.0/$dbu}]]
puts "BTERMS [llength [$block getBTerms]]"
set n_mx 0; set n_r180 0; set n_r0 0; set n_my 0; set nsram 0
foreach inst [$block getInsts] {
  set mn [[$inst getMaster] getName]
  if {[string match *sram256x8m8wm1* $mn]} {
    incr nsram
    lassign [$inst getLocation] x y
    puts [format "SRAM %s %.3f %.3f %s" [$inst getName] [expr {$x/2000.0}] [expr {$y/2000.0}] [$inst getOrient]]
  }
  if {$mn eq "gf180mcu_fd_sc_mcu9t5v0__aoi221_2"} {
    set o [$inst getOrient]
    switch -- $o { MX {incr n_mx} R180 {incr n_r180} R0 {incr n_r0} MY {incr n_my} }
  }
}
puts "AOI221_2 MX $n_mx R180 $n_r180 R0 $n_r0 MY $n_my SRAM $nsram INST [llength [$block getInsts]]"
foreach name {_11280_ _11106_ _11366_ _11339_ _11136_ _11474_ _11394_ _11408_ _11241_} {
  set i [$block findInst $name]
  if {$i eq "NULL" || $i eq ""} { puts "MISSING $name"; continue }
  puts [format "CELL %s %s %s" $name [[$i getMaster] getName] [$i getOrient]]
}
puts "PROBE_DONE"
exit
