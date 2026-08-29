# clkload27 nets + _18692_ / FF endpoints locations
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/setup_eco16/butterfold_top_co6a36_teco12.odb
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_db $src
set block [ord::get_db_block]
set dbu [[ord::get_db_tech] getDbUnitsPerMicron]
proc instinfo {block name dbu} {
  set i [$block findInst $name]
  if {$i eq "NULL" || $i eq ""} { puts "MISSING $name"; return }
  set bb [$i getBBox]
  puts "INST $name [[$i getMaster] getName] [$i getOrient] [expr [$bb xMin]*1.0/$dbu] [expr [$bb yMin]*1.0/$dbu] [expr [$bb xMax]*1.0/$dbu] [expr [$bb yMax]*1.0/$dbu]"
  foreach it [$i getITerms] {
    set pn [[$it getMTerm] getName]
    if {$pn eq "VDD" || $pn eq "VSS" || $pn eq "VNW" || $pn eq "VPW"} continue
    set n [$it getNet]
    set nn [expr {$n eq "NULL" || $n eq "" ? "UNCONNECTED" : [$n getName]}]
    set w "NA"
    if {$n ne "NULL" && $n ne ""} {
      set ww [$n getWire]
      set w [expr {$ww eq "NULL" || $ww eq "" ? "NULL" : "HASWIRE"}]
      puts "  PIN $pn net=$nn wire=$w terms=[llength [$n getITerms]] sig=[$n getSigType] special=[$n isSpecial]"
    } else {
      puts "  PIN $pn UNCONNECTED"
    }
  }
}
instinfo $block clkload27 $dbu
instinfo $block rebuffer265 $dbu
instinfo $block _18692_ $dbu
foreach n {_18287_ _18480_ _18288_ _18479_ _09092_ _12874_} { instinfo $block $n $dbu }
exit
