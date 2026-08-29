# CO.6a ECO: swap all MX aoi221_2 -> aoi221_1 (proven NW methodology).
# 9 MX aoi221_2 are the entire KLayout CO.6a set. 3 R0 aoi221_2 stay.
# PDK GDS of aoi221_2 MX has CO.6a; aoi221_1 MX does not. Mag cell == PDK cell.
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

set m1 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__aoi221_1]
if {$m1 eq "NULL"} { puts "MISSING_AOI221_1"; exit 1 }
set insts {_11280_ _11106_ _11366_ _11339_ _11136_ _11474_ _11394_ _11408_ _11241_}
set ripnets {}
foreach name $insts {
    set i [$block findInst $name]
    if {$i eq "NULL"} { puts "MISSING $name"; exit 1 }
    set o [$i getOrient]
    puts "BEFORE $name [[$i getMaster] getName] $o"
    if {$o ne "MX"} { puts "NOT_MX $name $o"; exit 1 }
    if {[catch {$i swapMaster $m1} msg]} { puts "SWAP_FAIL $name $msg"; exit 1 }
    $i setPlacementStatus FIRM
    puts "AFTER $name [[$i getMaster] getName] [$i getOrient]"
    foreach t [$i getITerms] {
        set pn [[$t getMTerm] getName]
        if {$pn eq "VDD" || $pn eq "VSS" || $pn eq "VNW" || $pn eq "VPW"} continue
        set n [$t getNet]
        if {$n eq "NULL"} continue
        dict set ripnets [$n getName] $n
    }
}
puts "RIP_COUNT [dict size $ripnets]"
dict for {nn n} $ripnets {
    if {[$n getWire] ne "" && [$n getWire] ne "NULL"} { catch {odb::dbWire_destroy [$n getWire]} }
    catch {$n clearGuides}
    puts "RIP $nn"
}
catch {global_connect}
if {[catch {check_placement}]} { puts "PLACE_BAD" } else { puts "PLACE_OK" }

foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
if {[catch {global_route -congestion_iterations 30 -verbose -guide_file $eco/co6a27.guide} gmsg]} { puts "GRT_WARN $gmsg" }
if {[catch {detailed_route -droute_end_iter 32 -or_seed 42 -verbose 1 -output_drc $eco/co6a27.drc} dmsg]} {
    puts "DRT_WARN $dmsg"
} else { puts "DRT_OK" }

# Fill leftover sites from 11.76 -> 6.16 um shrink.
set fills {}
set decaps {}
foreach lib [$db getLibs] {
    foreach m [$lib getMasters] {
        set n [$m getName]
        if {[string match "gf180mcu_fd_sc_mcu9t5v0__fillcap_*" $n]} { lappend decaps $n }
        if {[string match "gf180mcu_fd_sc_mcu9t5v0__fill_*" $n]} { lappend fills $n }
    }
}
set fill_list [concat [lsort -decreasing $decaps] [lsort -decreasing $fills]]
puts "FILL_BEFORE [llength [$block getInsts]]"
filler_placement $fill_list
add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
global_connect
puts "FILL_AFTER [llength [$block getInsts]]"
if {[catch {check_placement}]} { puts "PLACE_BAD" } else { puts "PLACE_OK" }

puts "ANT"; catch {check_antennas}
puts "PG_VDD"
if {[catch {check_power_grid -net VDD} e]} { puts "VDD_ERR $e" } else { puts "VDD_OK" }
puts "PG_VSS"
if {[catch {check_power_grid -net VSS} e]} { puts "VSS_ERR $e" } else { puts "VSS_OK" }

set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
extract_parasitics -ext_model_file $rcx_max
write_spef $cand/co6a27.max.spef
read_spef $cand/co6a27.max.spef
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
puts "ELEC"
report_check_types -max_slew -max_cap -max_fanout -violators
unset_case_analysis [get_ports rst_n]
puts "RESET_VISIBLE_SLEW [sta::max_slew_violation_count]"
puts "RESET_VISIBLE_CAP [sta::max_capacitance_violation_count]"
set_case_analysis 1 [get_ports rst_n]

write_db $cand/butterfold_top_co6a27.odb
write_def $cand/butterfold_top_co6a27.def
write_verilog $cand/butterfold_top.co6a27.v
write_verilog -include_pwr_gnd $cand/butterfold_top.co6a27.pnl.v
puts "CO6A27_DONE"
exit
