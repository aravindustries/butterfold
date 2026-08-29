# Characterize 9 aoi221_1 MX ZN electrical failures on eco27 ODB.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set cand $proto/physical/results/d03_ach_candidate
set out $proto/physical/reports/signoff/evidence/d03_ach/drc
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $cand/butterfold_top_co6a27.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
read_spef $cand/co6a27.max.spef
set block [ord::get_db_block]
set dbu [$block getDefUnits]
set insts {_11280_ _11106_ _11366_ _11339_ _11136_ _11474_ _11394_ _11408_ _11241_}
puts "INST MASTER ORIENT X Y W ROW_Y GAP_UM NET FANOUT SLEW CAP"
foreach name $insts {
    set i [$block findInst $name]
    set bb [$i getBBox]
    set x [expr {[$bb xMin]*1.0/$dbu}]
    set y [expr {[$bb yMin]*1.0/$dbu}]
    set w [expr {([$bb xMax]-[$bb xMin])*1.0/$dbu}]
    set gap [expr {(11.76 - $w)}]
    set zt [$i findITerm ZN]
    set n [$zt getNet]
    set nn [expr {$n eq "NULL" ? "-" : [$n getName]}]
    set fo 0
    if {$n ne "NULL"} { set fo [llength [$n getITerms]] }
    puts "ROW $name [[$i getMaster] getName] [$i getOrient] $x $y $w gap=$gap net=$nn fanout_iterms=$fo"
}
puts "ELEC"
report_check_types -max_slew -max_cap -max_fanout -violators
foreach name $insts {
    puts "PIN $name/ZN"
    catch {report_check_types -max_slew -max_cap -pins $name/ZN}
    set i [$block findInst $name]
    set n [[$i findITerm ZN] getNet]
    if {$n ne "NULL"} {
        puts "SINKS $name"
        foreach t [$n getITerms] {
            puts "  [$t getInst]/[[$t getMTerm] getName]"
        }
    }
}
# row orientations at those Y
puts "ROWS"
foreach row [$block getRows] {
    set rb [$row getBBox]
    set y0 [expr {[$rb yMin]*1.0/$dbu}]
    set ori [$row getOrient]
    foreach name $insts {
        set i [$block findInst $name]
        set iy [expr {[[$i getBBox] yMin]*1.0/$dbu}]
        if {abs($iy - $y0) < 0.1} {
            puts "ROWMATCH $name y=$y0 row_orient=$ori site=[[$row getSite] getName]"
        }
    }
}
puts "CHAR_DONE"
exit
