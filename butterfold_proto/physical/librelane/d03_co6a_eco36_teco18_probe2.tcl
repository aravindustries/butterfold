# Buffer sizes + holes near _10810_ / _10796_ / _05518_ path.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/setup_eco21/butterfold_top_co6a36_teco17.odb
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_db $src
set db [ord::get_db]
set block [ord::get_db_block]
set dbu [[ord::get_db_tech] getDbUnitsPerMicron]
foreach name {
  gf180mcu_fd_sc_mcu9t5v0__clkbuf_1
  gf180mcu_fd_sc_mcu9t5v0__clkbuf_2
  gf180mcu_fd_sc_mcu9t5v0__clkbuf_3
  gf180mcu_fd_sc_mcu9t5v0__clkbuf_4
  gf180mcu_fd_sc_mcu9t5v0__clkbuf_8
  gf180mcu_fd_sc_mcu9t5v0__buf_1
  gf180mcu_fd_sc_mcu9t5v0__buf_2
  gf180mcu_fd_sc_mcu9t5v0__buf_4
  gf180mcu_fd_sc_mcu9t5v0__buf_8
  gf180mcu_fd_sc_mcu9t5v0__inv_1
  gf180mcu_fd_sc_mcu9t5v0__inv_2
  gf180mcu_fd_sc_mcu9t5v0__inv_4
} {
  set m [$db findMaster $name]
  if {$m eq "NULL" || $m eq ""} { puts "NO $name"; continue }
  puts "W [string range $name 28 end] [expr [$m getWidth]*1.0/$dbu]"
}
proc dump_holes {block y0 dbu xmin xmax} {
  set site 5.04
  set ymin $y0
  set ymax [expr {$y0 + int($site*$dbu)}]
  set items {}
  foreach inst [$block getInsts] {
    set b [$inst getBBox]
    if {[$b yMax] <= $ymin || [$b yMin] >= $ymax} continue
    if {[$b xMax] < $xmin || [$b xMin] > $xmax} continue
    lappend items [list [$b xMin] [$b xMax] [$inst getName] [[$inst getMaster] getName]]
  }
  set items [lsort -integer -index 0 $items]
  set prev $xmin
  puts "HOLES y=[expr $ymin*1.0/$dbu] x=[expr $xmin*1.0/$dbu]..[expr $xmax*1.0/$dbu]"
  foreach t $items {
    set x1 [lindex $t 0]
    if {$x1 > $prev} {
      set gap [expr {($x1-$prev)*1.0/$dbu}]
      if {$gap >= 2.2} {
        puts "  GAP [expr $prev*1.0/$dbu]..[expr $x1*1.0/$dbu] w=$gap"
      }
    }
    set prev [lindex $t 1]
    puts "  OCC [expr [lindex $t 0]*1.0/$dbu]..[expr [lindex $t 1]*1.0/$dbu] [lindex $t 3] [lindex $t 2]"
  }
}
set inst [$block findInst _10810_]
set bb [$inst getBBox]
set y [$bb yMin]
puts "==== row _10810_ ===="
dump_holes $block $y $dbu [expr {[$bb xMin]-int(80*$dbu)}] [expr {[$bb xMax]+int(80*$dbu)}]
puts "==== row above ===="
dump_holes $block [expr {$y+int(5.04*$dbu)}] $dbu [expr {[$bb xMin]-int(40*$dbu)}] [expr {[$bb xMax]+int(40*$dbu)}]
puts "==== row below ===="
dump_holes $block [expr {$y-int(5.04*$dbu)}] $dbu [expr {[$bb xMin]-int(40*$dbu)}] [expr {[$bb xMax]+int(40*$dbu)}]
set i2 [$block findInst _10796_]
set b2 [$i2 getBBox]
puts "==== row _10796_ ===="
dump_holes $block [$b2 yMin] $dbu [expr {[$b2 xMin]-int(40*$dbu)}] [expr {[$b2 xMax]+int(60*$dbu)}]
# drivers of _10810_
foreach it [$inst getITerms] {
  set pn [[$it getMTerm] getName]
  if {$pn eq "VDD" || $pn eq "VSS" || $pn eq "VNW" || $pn eq "VPW"} continue
  set n [$it getNet]
  puts "NET $pn [$n getName] terms:"
  foreach t [$n getITerms] {
    set ii [$t getInst]
    puts "  [$ii getName]/[[$t getMTerm] getName] [[$ii getMaster] getName] [$ii getOrient] loc=[expr [[$ii getBBox] xMin]*1.0/$dbu] [expr [[$ii getBBox] yMin]*1.0/$dbu]"
  }
}
exit
