# eco30: R180 nine aoi221_2 on pgfix, freeze all other nets, DRT only the 38.
# eco28/29 full TritonRoute rewrote via landings (M2.3) and one M4.2a.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set cand $proto/physical/results/d03_ach_candidate
set eco $proto/physical/results/d03_ach_setup_eco
set out $proto/physical/reports/signoff/evidence/d03_ach/drc
file mkdir $out
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $cand/butterfold_top_pgfix.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
set db [ord::get_db]
set block [ord::get_db_block]
foreach inst [$block getInsts] { $inst setPlacementStatus FIRM }

proc sta_name {nn} { return [string map {\\[ [ \\] ]} $nn] }

set insts {_11280_ _11106_ _11366_ _11339_ _11136_ _11474_ _11394_ _11408_ _11241_}
array set rip {}
foreach name $insts {
    set i [$block findInst $name]
    if {$i eq "NULL"} { puts "MISSING $name"; exit 1 }
    lassign [$i getLocation] x y
    puts "BEFORE $name [[$i getMaster] getName] [$i getOrient] $x $y"
    $i setPlacementStatus PLACED
    $i setOrient R180
    $i setLocation $x $y
    $i setPlacementStatus FIRM
    puts "AFTER $name [[$i getMaster] getName] [$i getOrient]"
    foreach t [$i getITerms] {
        set pn [[$t getMTerm] getName]
        if {$pn eq "VDD" || $pn eq "VSS" || $pn eq "VNW" || $pn eq "VPW"} continue
        set n [$t getNet]
        if {$n eq "NULL"} continue
        set rip([$n getName]) $n
    }
}
puts "RIP_COUNT [array size rip]"

# Freeze every other signal net so DRT cannot rewrite pgfix via landings.
set nfix 0
set sample_wt ""
foreach n [$block getNets] {
    if {[$n isSpecial]} continue
    set nn [$n getName]
    if {[info exists rip($nn)]} continue
    catch {$n setDoNotTouch 1}
    if {[catch {$n setWireType "FIXED"} e]} {
        if {$nfix == 0} { puts "SETWIRETYPE_ERR $e wt=[$n getWireType]" }
    }
    incr nfix
    if {$sample_wt eq ""} { set sample_wt [$n getWireType] }
}
puts "FROZEN $nfix SAMPLE_WT $sample_wt"

set sta_names {}
foreach nn [array names rip] {
    set n $rip($nn)
    if {[$n getWire] ne "" && [$n getWire] ne "NULL"} { catch {odb::dbWire_destroy [$n getWire]} }
    catch {$n clearGuides}
    catch {$n setDoNotTouch 0}
    lappend sta_names [sta_name $nn]
    puts "RIP $nn sta=[sta_name $nn]"
}
catch {global_connect}
if {[catch {check_placement}]} { puts "PLACE_BAD"; exit 1 } else { puts "PLACE_OK" }

puts "SET_NETS_TO_ROUTE [llength $sta_names]"
if {[catch {set_nets_to_route $sta_names} e]} { puts "SET_NETS_ERR $e" }
foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
if {[catch {global_route -congestion_iterations 30 -verbose -guide_file $eco/co6a30.guide} gmsg]} {
    puts "GRT_WARN $gmsg"
}
if {[catch {detailed_route -droute_end_iter 32 -or_seed 42 -verbose 1 -output_drc $eco/co6a30.drc} dmsg]} {
    puts "DRT_WARN $dmsg"
} else { puts "DRT_OK" }

set nopen 0
foreach n [$block getNets] {
    if {[$n isSpecial]} continue
    set w [$n getWire]
    if {$w eq "" || $w eq "NULL"} {
        incr nopen
        puts "OPEN [$n getName]"
    }
}
puts "OPEN_AFTER $nopen"

puts "ANT"; catch {check_antennas}
puts "PG_VDD"; if {[catch {check_power_grid -net VDD} e]} { puts "VDD_ERR $e" } else { puts "VDD_OK" }
puts "PG_VSS"; if {[catch {check_power_grid -net VSS} e]} { puts "VSS_ERR $e" } else { puts "VSS_OK" }

extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
write_spef $cand/co6a30.max.spef
read_spef $cand/co6a30.max.spef
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
puts "SLEW_COUNT [sta::max_slew_violation_count]"
puts "CAP_COUNT [sta::max_capacitance_violation_count]"
puts "FANOUT_COUNT [sta::max_fanout_violation_count]"
unset_case_analysis [get_ports rst_n]
puts "RESET_VISIBLE_SLEW [sta::max_slew_violation_count]"
puts "RESET_VISIBLE_CAP [sta::max_capacitance_violation_count]"
set_case_analysis 1 [get_ports rst_n]

write_db $cand/butterfold_top_co6a30.odb
write_def $cand/butterfold_top_co6a30.def
write_verilog -include_pwr_gnd $cand/butterfold_top.co6a30.pnl.v
puts "CO6A30_DONE"
exit
