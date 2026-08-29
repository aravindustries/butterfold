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
array set rows {}
foreach inst [$block getInsts] {
  set b [$inst getBBox]
  set yk [expr {int(([$b yMin] - $ymin)/$row_h)}]
  lappend rows($yk) [list [$b xMin] [$b xMax]]
}
proc gaps_in_window {rows ykmin ykmax xmin xmax need dbu ymin row_h wx1 wx2 wy1 wy2 limit} {
  set shown 0
  foreach yk [lsort -integer [array names rows]] {
    if {$yk < $ykmin || $yk > $ykmax} continue
    set y [expr {$ymin + $yk*$row_h}]
    set yum [expr {$y*1.0/$dbu}]
    if {$yum < $wy1 || $yum > $wy2} continue
    set items [lsort -integer -index 0 $rows($yk)]
    set prev $xmin
    foreach t $items {
      set x1 [lindex $t 0]
      set wpx [expr {$x1 - $prev}]
      if {$wpx >= $need} {
        set xL [expr {$prev*1.0/$dbu}]
        set xR [expr {$x1*1.0/$dbu}]
        set yum [expr {$y*1.0/$dbu}]
        if {$xR >= $wx1 && $xL <= $wx2} {
          incr shown
          if {$shown <= $limit} {
            puts "GAP y=$yum x=$xL..$xR w=[expr $wpx*1.0/$dbu]"
          }
        }
      }
      if {[lindex $t 1] > $prev} { set prev [lindex $t 1] }
    }
  }
  puts "shown $shown"
}
puts "==== ROOT near rst_n y~273 x<80 ===="
gaps_in_window rows 0 400 $xmin $xmax [expr {int(34.72*$dbu)}] $dbu $ymin $row_h 6 80 250 300 15
puts "==== QSW ===="
gaps_in_window rows 0 400 $xmin $xmax $need $dbu $ymin $row_h 50 400 100 700 8
puts "==== QSE ===="
gaps_in_window rows 0 400 $xmin $xmax $need $dbu $ymin $row_h 600 1050 100 700 8
puts "==== QNW ===="
gaps_in_window rows 0 400 $xmin $xmax $need $dbu $ymin $row_h 50 400 900 1500 8
puts "==== QNE ===="
gaps_in_window rows 0 400 $xmin $xmax $need $dbu $ymin $row_h 600 1050 900 1500 8
exit
