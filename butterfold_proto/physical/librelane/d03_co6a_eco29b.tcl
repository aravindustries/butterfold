# Route the 6 fifo nets eco29 missed (STA name escaping of \[ \]).
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set cand $proto/physical/results/d03_ach_candidate
set eco $proto/physical/results/d03_ach_setup_eco
set out $proto/physical/reports/signoff/evidence/d03_ach/drc
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $cand/butterfold_top_co6a29.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
set block [ord::get_db_block]
foreach inst [$block getInsts] { $inst setPlacementStatus FIRM }

set sta_names {}
set nopen 0
foreach n [$block getNets] {
    if {[$n isSpecial]} continue
    set w [$n getWire]
    if {$w eq "" || $w eq "NULL"} {
        incr nopen
        set nn [$n getName]
        set sta [string map {\\[ [ \\] ]} $nn]
        lappend sta_names $sta
        catch {$n clearGuides}
        puts "UNROUTED odb=$nn sta=$sta"
    }
}
puts "OPEN_NETS $nopen"
if {$nopen == 0} { puts "NO_OPENS"; exit 0 }

puts "SET_NETS_TO_ROUTE $sta_names"
if {[catch {set_nets_to_route $sta_names} e]} { puts "SET_NETS_ERR $e" }
foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
if {[catch {global_route -congestion_iterations 30 -verbose -guide_file $eco/co6a29b.guide} gmsg]} {
    puts "GRT_WARN $gmsg"
}
if {[catch {detailed_route -droute_end_iter 32 -or_seed 42 -verbose 1 -output_drc $eco/co6a29b.drc} dmsg]} {
    puts "DRT_WARN $dmsg"
} else { puts "DRT_OK" }

set nopen2 0
foreach n [$block getNets] {
    if {[$n isSpecial]} continue
    set w [$n getWire]
    if {$w eq "" || $w eq "NULL"} {
        incr nopen2
        puts "STILL_OPEN [$n getName]"
    }
}
puts "OPEN_AFTER $nopen2"
puts "ANT"; catch {check_antennas}
puts "PG_VDD"; if {[catch {check_power_grid -net VDD} e]} { puts "VDD_ERR $e" } else { puts "VDD_OK" }
puts "PG_VSS"; if {[catch {check_power_grid -net VSS} e]} { puts "VSS_ERR $e" } else { puts "VSS_OK" }
if {[catch {check_placement}]} { puts "PLACE_BAD" } else { puts "PLACE_OK" }

extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
write_spef $cand/co6a29b.max.spef
read_spef $cand/co6a29b.max.spef
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
puts "SLEW_COUNT [sta::max_slew_violation_count]"
puts "CAP_COUNT [sta::max_capacitance_violation_count]"
puts "FANOUT_COUNT [sta::max_fanout_violation_count]"
unset_case_analysis [get_ports rst_n]
puts "RESET_VISIBLE_SLEW [sta::max_slew_violation_count]"
puts "RESET_VISIBLE_CAP [sta::max_capacitance_violation_count]"
set_case_analysis 1 [get_ports rst_n]
report_check_types -max_slew -max_cap -max_fanout -violators > $out/co6a29b_electrical.rpt

write_db $cand/butterfold_top_co6a29b.odb
write_def $cand/butterfold_top_co6a29b.def
write_verilog -include_pwr_gnd $cand/butterfold_top.co6a29b.pnl.v
puts "CO6A29B_DONE"
exit
