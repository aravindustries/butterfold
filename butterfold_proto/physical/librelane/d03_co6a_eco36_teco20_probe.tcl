# Masters of liberty cap/slew output violators on teco18, plus rst_n wire bbox.
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
  _09877_ _12553_ _09422_ _11198_ _10216_ _12474_ _11434_ _11083_ _13042_
  _15762_ _17231_ _12214_ _12577_ _12601_ _12569_ _11765_ _11447_ _15865_
  _11183_ _10224_ clone309 clone396 _09901_ _09889_ _12458_ _09907_ _12188_
  _12617_ _09911_ _11094_ _11120_ _10243_ _09860_ _11325_ _11925_ _09910_
  _12482_ _09563_ _09912_ _12169_ _11319_ _11559_ clone388 _11075_ _11898_
  _09657_ _19230_ _11461_ _11527_ _09895_ _12466_ _19232_ _12227_ _11150_
  _09471_ _11785_ _12450_ input1 input2 input3 input4 input5 input6 input7 input8
  _11198_ _12553_ _09877_ _09422_ _11447_ _12474_ _11434_ _11183_ _20030_
}
set seen {}
foreach n $insts {
  if {[lsearch -exact $seen $n] >= 0} continue
  lappend seen $n
  set i [$block findInst $n]
  if {$i eq "NULL" || $i eq ""} { puts "NO $n"; continue }
  set m [[$i getMaster] getName]
  set b [$i getBBox]
  puts "INST $n $m [$i getOrient] w=[expr ([$b xMax]-[$b xMin])*1.0/$dbu] x=[expr [$b xMin]*1.0/$dbu] y=[expr [$b yMin]*1.0/$dbu]"
}
set n [$block findNet rst_n]
set w [$n getWire]
puts "RST_N terms=[llength [$n getITerms]] wire=[expr {$w eq {NULL} || $w eq {} ? {NULL} : {HASWIRE}}]"
if {$w ne "NULL" && $w ne ""} {
  puts "RST_N wire_len_dbu? try bbox"
  catch {puts "WIRE methods ok"}
}
# decoder opcodes
if {$w ne "NULL" && $w ne ""} {
  set dec [odb::dbWireDecoder]
  $dec begin $w
  set nops 0
  set pts 0
  while {$nops < 30} {
    set code [$dec next]
    if {$code == 0} { puts "OP DONE"; break }
    incr nops
    puts "OP $code"
  }
  puts "NOPS $nops"
}
exit
