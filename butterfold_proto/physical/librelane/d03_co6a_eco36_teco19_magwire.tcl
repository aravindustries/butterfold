# Find non-orthogonal signal wires that cause DRT-1010.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_db $proto/physical/results/d03_ach_candidate/co6a36/setup_eco23/butterfold_top_co6a36_teco19_preroute.odb
set block [ord::get_db_block]
set nnet 0
set nbad 0
foreach net [$block getNets] {
  if {[$net isSpecial]} continue
  set w [$net getWire]
  if {$w eq "NULL" || $w eq ""} continue
  incr nnet
  set dec [odb::dbWireDecoder]
  $dec begin $w
  set px -1; set py -1; set have 0
  set bad 0
  while {1} {
    set op [$dec peek]
    if {$op == 0} { break }
    # opcodes: PATH=0? use next
    set code [$dec next]
    if {$code == 0} { break }
    # dbWireDecoder::POINT is typically 1 or similar; try getCoord
    if {[catch {lassign [$dec getPoint] x y}]} { continue }
    if {$have} {
      set dx [expr {abs($x-$px)}]
      set dy [expr {abs($y-$py)}]
      if {$dx > 0 && $dy > 0} {
        set bad 1
        break
      }
    }
    set px $x; set py $y; set have 1
  }
  if {$bad} {
    incr nbad
    if {$nbad <= 40} { puts "NONORTHO [$net getName] terms=[llength [$net getITerms]]" }
  }
}
puts "WIRED_SIGNAL $nnet NONORTHO $nbad"
exit
