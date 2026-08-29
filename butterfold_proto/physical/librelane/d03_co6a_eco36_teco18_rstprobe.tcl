# Probe rst_n / SETN drivers and fanout on teco18.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/setup_eco22
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_db $src/butterfold_top_co6a36_teco18.odb
set block [ord::get_db_block]
set dbu [[ord::get_db_tech] getDbUnitsPerMicron]
proc netinfo {block name} {
  set n [$block findNet $name]
  if {$n eq "NULL" || $n eq ""} { puts "NONET $name"; return }
  set w [$n getWire]
  puts "NET $name terms=[llength [$n getITerms]] bterms=[llength [$n getBTerms]] sig=[$n getSigType] special=[$n isSpecial] wire=[expr {$w eq {NULL} || $w eq {} ? {NULL} : {HASWIRE}}]"
  set ndrv 0
  foreach it [$n getITerms] {
    set pn [[$it getMTerm] getName]
    set io [[$it getMTerm] getIoType]
    set inst [$it getInst]
    set mn [[$inst getMaster] getName]
    if {$io eq "OUTPUT"} {
      incr ndrv
      lassign [$inst getLocation] x y
      puts "  DRV [$inst getName]/$pn $mn [$inst getOrient] loc=[expr $x*1.0/[[ord::get_db_tech] getDbUnitsPerMicron]] [expr $y*1.0/[[ord::get_db_tech] getDbUnitsPerMicron]]"
    }
  }
  puts "  NDRV $ndrv"
  set sinks 0
  array set spin {}
  foreach it [$n getITerms] {
    set pn [[$it getMTerm] getName]
    if {[[$it getMTerm] getIoType] eq "INPUT"} {
      incr sinks
      incr spin($pn)
    }
  }
  puts "  NSINK $sinks"
  foreach k [lsort [array names spin]] { puts "  SINKPIN $k $spin($k)" }
}
netinfo $block rst_n
# find SETN nets of the violators
foreach inst {_20027_ _19817_ _20013_ _19996_ _20056_ _20032_ _20024_} {
  set i [$block findInst $inst]
  if {$i eq "NULL"} { puts "NO $inst"; continue }
  set it [$i findITerm SETN]
  if {$it eq "NULL"} { puts "NOSETN $inst"; continue }
  set n [$it getNet]
  puts "SETN $inst net=[$n getName] terms=[llength [$n getITerms]]"
}
# input buffers
foreach inst [$block getInsts] {
  set n [$inst getName]
  if {[string match "input*" $n]} {
    set mn [[$inst getMaster] getName]
    puts "INPUTCELL $n $mn"
    foreach it [$inst getITerms] {
      set pn [[$it getMTerm] getName]
      if {$pn eq "VDD" || $pn eq "VSS" || $pn eq "VNW" || $pn eq "VPW"} continue
      set net [$it getNet]
      set nn [expr {$net eq "NULL" || $net eq "" ? "UNCONNECTED" : [$net getName]}]
      puts "  $pn $nn"
    }
  }
}
# rst_n bterm
foreach bt [$block getBTerms] {
  if {[$bt getName] eq "rst_n"} {
    puts "BTERM rst_n net=[[$bt getNet] getName]"
  }
}
puts "RSTPROBE_DONE"
exit
