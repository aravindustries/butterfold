# Which *_1 cap/slew output drivers on teco18 can KEEP_WIRES upsize to *_2.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_db $proto/physical/results/d03_ach_candidate/co6a36/setup_eco22/butterfold_top_co6a36_teco18.odb
set db [ord::get_db]
set block [ord::get_db_block]
set dbu [[ord::get_db_tech] getDbUnitsPerMicron]
set insts {
  _09877_ _12553_ _09422_ _10216_ _12474_ _11434_ _11083_ _13042_
  _15762_ _17231_ _12214_ _12577_ _12601_ _12569_ _11765_ _15865_
  _10224_ clone309 clone396 _09901_ _09889_ _12458_ _09907_ _12188_
  _12617_ _09911_ _11094_ _11120_ _10243_ _09860_ _11325_ _11925_
  _09910_ _12482_ _09563_ _09912_ _12169_ _11319_ _11559_ clone388
  _11075_ _11898_ _09657_ _11461_ _09895_ _12466_ _12227_ _09471_
  _11785_ _12450_
}
proc pin_xbox {master pin dbu} {
  set mt [$master findMTerm $pin]
  if {$mt eq "NULL"} { return {} }
  set xmin 1e99; set xmax -1e99
  foreach mp [$mt getMPins] {
    foreach b [$mp getGeometry] {
      if {[$b xMin] < $xmin} { set xmin [$b xMin] }
      if {[$b xMax] > $xmax} { set xmax [$b xMax] }
    }
  }
  if {$xmin > $xmax} { return {} }
  return [list [expr {$xmin*1.0/$dbu}] [expr {$xmax*1.0/$dbu}]]
}
proc gap_right {block inst} {
  set b [$inst getBBox]
  set ymin [$b yMin]; set ymax [$b yMax]; set xmax [$b xMax]
  set best 1e99
  foreach o [$block getInsts] {
    if {$o eq $inst} continue
    set ob [$o getBBox]
    if {[$ob yMax] <= $ymin || [$ob yMin] >= $ymax} continue
    if {[$ob xMin] >= $xmax && [$ob xMin] < $best} { set best [$ob xMin] }
  }
  set dbu [[ord::get_db_tech] getDbUnitsPerMicron]
  if {$best > 1e98} { return 999 }
  return [expr {($best-$xmax)*1.0/$dbu}]
}
proc gap_left {block inst} {
  set b [$inst getBBox]
  set ymin [$b yMin]; set ymax [$b yMax]; set xmin [$b xMin]
  set best -1e99
  foreach o [$block getInsts] {
    if {$o eq $inst} continue
    set ob [$o getBBox]
    if {[$ob yMax] <= $ymin || [$ob yMin] >= $ymax} continue
    if {[$ob xMax] <= $xmin && [$ob xMax] > $best} { set best [$ob xMax] }
  }
  set dbu [[ord::get_db_tech] getDbUnitsPerMicron]
  if {$best < -1e98} { return 999 }
  return [expr {($xmin-$best)*1.0/$dbu}]
}
set ok {}
foreach n $insts {
  set i [$block findInst $n]
  if {$i eq "NULL"} continue
  set src [[$i getMaster] getName]
  if {![regexp {^(gf180mcu_fd_sc_mcu9t5v0__[a-z0-9]+)_1$} $src -> stem]} {
    puts "SKIP $n not *_1 $src"; continue
  }
  set tgt ${stem}_2
  set m2 [$db findMaster $tgt]
  if {$m2 eq "NULL"} { puts "NOMASTER $n $tgt"; continue }
  set w1 [expr {[[$i getMaster] getWidth]*1.0/$dbu}]
  set w2 [expr {[$m2 getWidth]*1.0/$dbu}]
  set dw [expr {$w2-$w1}]
  set gr [gap_right $block $i]
  set gl [gap_left $block $i]
  set fitR [expr {$gr+0.001 >= $dw}]
  set fitL [expr {$gl+$gr+0.001 >= $dw}]
  puts [format "CELL %-12s %s -> %s dw=%.2f gapR=%.2f gapL=%.2f fitR=%d" $n $src $tgt $dw $gr $gl $fitR]
  if {$fitR} { lappend ok $n }
}
puts "FIT_RIGHT [llength $ok] $ok"
exit
