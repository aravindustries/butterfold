# pgfix ODB sanity: DIE/CORE/pins/SRAM/placement/PG/antenna.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set cand $proto/physical/results/d03_ach_candidate
set c max_ss_125C_4v50
define_corners $c
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty -corner $c $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_db $cand/butterfold_top_pgfix.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [all_clocks]

puts "==== DIE / CORE ===="
puts [ord::get_db_block]

set block [ord::get_db_block]
set die [$block getDieArea]
set core [$block getCoreArea]
set dbu [$block getDefUnits]
puts "DBU $dbu"
puts [format "DIE um %.4f %.4f %.4f %.4f" \
    [expr {[$die xMin]*1.0/$dbu}] [expr {[$die yMin]*1.0/$dbu}] \
    [expr {[$die xMax]*1.0/$dbu}] [expr {[$die yMax]*1.0/$dbu}]]
puts [format "CORE um %.4f %.4f %.4f %.4f" \
    [expr {[$core xMin]*1.0/$dbu}] [expr {[$core yMin]*1.0/$dbu}] \
    [expr {[$core xMax]*1.0/$dbu}] [expr {[$core yMax]*1.0/$dbu}]]

puts "==== INST / SRAM / PINS ===="
set ninst 0
set nsram 0
foreach inst [$block getInsts] {
    incr ninst
    set mn [[$inst getMaster] getName]
    if {[string match *sram256x8m8wm1* $mn]} {
        incr nsram
        puts [format "SRAM %s %s (%.3f %.3f)" [$inst getName] $mn \
            [expr {[[$inst getBBox] xMin]*1.0/$dbu}] \
            [expr {[[$inst getBBox] yMin]*1.0/$dbu}]]
    }
}
puts "INST $ninst SRAM $nsram BTERMS [llength [$block getBTerms]]"
foreach bt [$block getBTerms] {
    set boxes {}
    foreach bp [$bt getBPins] {
        foreach box [$bp getBoxes] {
            lappend boxes [format "%s %.3f %.3f %.3f %.3f" \
                [[$box getTechLayer] getName] \
                [expr {[$box xMin]*1.0/$dbu}] [expr {[$box yMin]*1.0/$dbu}] \
                [expr {[$box xMax]*1.0/$dbu}] [expr {[$box yMax]*1.0/$dbu}]]
        }
    }
    puts "PIN [$bt getName] $boxes"
}

puts "==== PLACEMENT ===="
check_placement -verbose

puts "==== POWER GRID ===="
puts "VDD"
check_power_grid -net VDD
puts "VSS"
check_power_grid -net VSS

puts "==== ANTENNA ===="
check_antennas -report_file $cand/irdrop/pgfix_antennas.rpt

# ACH pin-centered VSRC for IR (not the north-edge leftover file).
file mkdir $cand/irdrop
set fv [open $cand/irdrop/VDD.ach.vsrc w]
set fs [open $cand/irdrop/VSS.ach.vsrc w]
foreach bt [$block getBTerms] {
    set nm [$bt getName]
    if {$nm ne "VDD" && $nm ne "VSS"} { continue }
    set fh [expr {$nm eq "VDD" ? $fv : $fs}]
    set volt [expr {$nm eq "VDD" ? 4.500 : 0.000}]
    foreach bp [$bt getBPins] {
        foreach box [$bp getBoxes] {
            set cx [expr {([$box xMin]+[$box xMax])*0.5/$dbu}]
            set cy [expr {([$box yMin]+[$box yMax])*0.5/$dbu}]
            puts $fh [format "%.3f %.3f %.3f" $cx $cy $volt]
        }
    }
}
close $fv
close $fs
puts "wrote ACH vsrc"
puts "PGFIX_CHECKS_DONE"
exit
