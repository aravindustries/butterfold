# Find stdcell-row gaps >= 28 um (buf_16) and >= 34.72 (buf_20).
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_db $proto/physical/results/d03_ach_candidate/co6a36/setup_eco22/butterfold_top_co6a36_teco18.odb
set block [ord::get_db_block]
set dbu [[ord::get_db_tech] getDbUnitsPerMicron]
set core [$block getCoreArea]
set xmin [$core xMin]
set xmax [$core xMax]
set ymin [$core yMin]
set ymax [$core yMax]
set row_h [expr {int(5.04*$dbu)}]
set need [expr {int(28.0*$dbu)}]
# exclude the 5 new names if present
array set skip {}
foreach name {teco19_rst_root wire413 load_slew414 load_slew415 load_slew416} { set skip($name) 1 }
# bucket insts by row yMin
array set rows {}
foreach inst [$block getInsts] {
  if {[info exists skip([$inst getName])]} continue
  set b [$inst getBBox]
  set y [$b yMin]
  # snap to row
  set yk [expr {int(($y - $ymin)/$row_h)}]
  lappend rows($yk) [list [$b xMin] [$b xMax]]
}
set ngap 0
set shown 0
foreach yk [lsort -integer [array names rows]] {
  set y [expr {$ymin + $yk*$row_h}]
  if {$y < $ymin || $y+$row_h > $ymax} continue
  set items [lsort -integer -index 0 $rows($yk)]
  set prev $xmin
  foreach t $items {
    set x1 [lindex $t 0]
    if {$x1 - $prev >= $need} {
      incr ngap
      set w [expr {($x1-$prev)*1.0/$dbu}]
      if {$shown < 40 && $w >= 28.0} {
        puts "GAP y=[expr $y*1.0/$dbu] x=[expr $prev*1.0/$dbu]..[expr $x1*1.0/$dbu] w=$w"
        incr shown
      }
    }
    if {[lindex $t 1] > $prev} { set prev [lindex $t 1] }
  }
  if {$xmax - $prev >= $need} {
    incr ngap
    set w [expr {($xmax-$prev)*1.0/$dbu}]
    if {$shown < 40 && $w >= 28.0} {
      puts "GAP y=[expr $y*1.0/$dbu] x=[expr $prev*1.0/$dbu]..[expr $xmax*1.0/$dbu] w=$w"
      incr shown
    }
  }
}
puts "NGAP28 $ngap shown $shown"
exit
