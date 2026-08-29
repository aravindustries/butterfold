# Wider same-row occupancy around rebuffer265, plus aoi22_2 fit at _10810_.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/setup_eco16/butterfold_top_co6a36_teco12.odb
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_db $src
set db [ord::get_db]
set block [ord::get_db_block]
set dbu [[ord::get_db_tech] getDbUnitsPerMicron]

proc dump_row {block inst extra dbu} {
  set bbox [$inst getBBox]
  set xmin [$bbox xMin]
  set xmax [$bbox xMax]
  set ymin [$bbox yMin]
  set ymax [$bbox yMax]
  puts "ROW around [$inst getName] extra_um=[expr $extra*1.0/$dbu]"
  set items {}
  foreach other [$block getInsts] {
    set ob [$other getBBox]
    if {[$ob yMax] <= $ymin || [$ob yMin] >= $ymax} continue
    if {[$ob xMax] <= [expr {$xmin - $extra}] || [$ob xMin] >= [expr {$xmax + $extra}]} continue
    lappend items [list [$ob xMin] [$other getName] [[$other getMaster] getName] [$other getOrient] [expr {[$ob xMin]*1.0/$dbu}] [expr {[$ob xMax]*1.0/$dbu}] [expr {([$ob xMax]-[$ob xMin])*1.0/$dbu}]]
  }
  set items [lsort -integer -index 0 $items]
  foreach t $items {
    puts "  [lindex $t 4]..[lindex $t 5] w=[lindex $t 6] [lindex $t 2] [lindex $t 1] [lindex $t 3]"
  }
}

set inst [$block findInst rebuffer265]
dump_row $block $inst [expr {int(80*$dbu)}] $dbu

puts "---- _10810_ ----"
set i2 [$block findInst _10810_]
lassign [$i2 getLocation] x0 y0
set bb [$i2 getBBox]
puts "master=[[$i2 getMaster] getName] orient=[$i2 getOrient] loc=[expr $x0*1.0/$dbu] [expr $y0*1.0/$dbu] w=[expr ([$bb xMax]-[$bb xMin])*1.0/$dbu]"
dump_row $block $i2 [expr {int(40*$dbu)}] $dbu
foreach sz {1 2 4} {
  set m [$db findMaster gf180mcu_fd_sc_mcu9t5v0__aoi22_$sz]
  if {$m eq "NULL"} { puts "NO aoi22_$sz"; continue }
  puts "MASTER aoi22_$sz w=[expr [$m getWidth]*1.0/$dbu]"
}
puts "---- _10796_ ----"
set i3 [$block findInst _10796_]
set bb3 [$i3 getBBox]
puts "master=[[$i3 getMaster] getName] orient=[$i3 getOrient] w=[expr ([$bb3 xMax]-[$bb3 xMin])*1.0/$dbu]"
dump_row $block $i3 [expr {int(30*$dbu)}] $dbu
puts "---- _09541_ ----"
set i4 [$block findInst _09541_]
set bb4 [$i4 getBBox]
puts "master=[[$i4 getMaster] getName] orient=[$i4 getOrient] w=[expr ([$bb4 xMax]-[$bb4 xMin])*1.0/$dbu] loc=[expr [$bb4 xMin]*1.0/$dbu] [expr [$bb4 yMin]*1.0/$dbu]"
dump_row $block $i4 [expr {int(30*$dbu)}] $dbu
exit
