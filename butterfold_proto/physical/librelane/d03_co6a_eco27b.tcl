# Buffer ZN of the 9 swapped aoi221_1 MX using leftover 5.60 µm sites (buf_3).
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set cand $proto/physical/results/d03_ach_candidate
set eco $proto/physical/results/d03_ach_setup_eco
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $cand/butterfold_top_co6a27.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
set db [ord::get_db]
set block [ord::get_db_block]
set dbu [$block getDefUnits]
foreach inst [$block getInsts] { $inst setPlacementStatus FIRM }

set bufm [$db findMaster gf180mcu_fd_sc_mcu9t5v0__buf_3]
if {$bufm eq "NULL"} { puts "MISSING_BUF3"; exit 1 }
set insts {_11280_ _11106_ _11366_ _11339_ _11136_ _11474_ _11394_ _11408_ _11241_}
set ripnets {}

proc rip_net {n} {
    if {$n eq "NULL"} { return }
    if {[$n getWire] ne "" && [$n getWire] ne "NULL"} { catch {odb::dbWire_destroy [$n getWire]} }
    catch {$n clearGuides}
}

foreach name $insts {
    set aoi [$block findInst $name]
    set bb [$aoi getBBox]
    set gx1 [$bb xMax]
    set gy1 [$bb yMin]
    set gx2 [expr {$gx1 + int(5.60 * $dbu)}]
    set gy2 [$bb yMax]
    # destroy fillers occupying the leftover 5.60 µm
    set kill {}
    foreach inst [$block getInsts] {
        set ib [$inst getBBox]
        if {[$ib xMin] >= $gx1 && [$ib xMax] <= $gx2 && [$ib yMin] >= $gy1 && [$ib yMax] <= $gy2} {
            if {$inst ne $aoi} { lappend kill $inst }
        }
    }
    foreach inst $kill {
        puts "KILL_FILL [$inst getName] [[$inst getMaster] getName]"
        odb::dbInst_destroy $inst
    }
    set bname "co6a_buf_$name"
    set ni [odb::dbInst_create $block $bufm $bname]
    $ni setOrient [$aoi getOrient]
    $ni setLocation $gx1 $gy1
    $ni setPlacementStatus FIRM
    puts "BUF $bname at [expr {$gx1*1.0/$dbu}] [expr {$gy1*1.0/$dbu}] w=[[$ni getMaster] getWidth]"

    set zt [$aoi findITerm ZN]
    set old [$zt getNet]
    set nnet [odb::dbNet_create $block "co6a_mid_$name"]
    $zt disconnect
    $zt connect $nnet
    [$ni findITerm I] connect $nnet
    [$ni findITerm Z] connect $old
    dict set ripnets [$old getName] $old
    dict set ripnets [$nnet getName] $nnet
}

dict for {nn n} $ripnets { rip_net $n; puts "RIP $nn" }
catch {global_connect}
if {[catch {check_placement}]} { puts "PLACE_BAD" } else { puts "PLACE_OK" }

foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
if {[catch {global_route -congestion_iterations 30 -verbose -guide_file $eco/co6a27b.guide} gmsg]} { puts "GRT_WARN $gmsg" }
if {[catch {detailed_route -droute_end_iter 32 -or_seed 42 -verbose 1 -output_drc $eco/co6a27b.drc} dmsg]} {
    puts "DRT_WARN $dmsg"
} else { puts "DRT_OK" }

set fills {}
set decaps {}
foreach lib [$db getLibs] {
    foreach m [$lib getMasters] {
        set n [$m getName]
        if {[string match "gf180mcu_fd_sc_mcu9t5v0__fillcap_*" $n]} { lappend decaps $n }
        if {[string match "gf180mcu_fd_sc_mcu9t5v0__fill_*" $n]} { lappend fills $n }
    }
}
filler_placement [concat [lsort -decreasing $decaps] [lsort -decreasing $fills]]
add_global_connection -net VDD -inst_pattern .* -pin_pattern VDD -power
add_global_connection -net VDD -inst_pattern .* -pin_pattern VNW -power
add_global_connection -net VSS -inst_pattern .* -pin_pattern VSS -ground
add_global_connection -net VSS -inst_pattern .* -pin_pattern VPW -ground
global_connect
if {[catch {check_placement}]} { puts "PLACE_BAD" } else { puts "PLACE_OK" }
puts "ANT"; catch {check_antennas}
puts "PG_VDD"; if {[catch {check_power_grid -net VDD} e]} { puts "VDD_ERR $e" } else { puts "VDD_OK" }
puts "PG_VSS"; if {[catch {check_power_grid -net VSS} e]} { puts "VSS_ERR $e" } else { puts "VSS_OK" }

extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
write_spef $cand/co6a27b.max.spef
read_spef $cand/co6a27b.max.spef
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
puts "ELEC"
report_check_types -max_slew -max_cap -max_fanout -violators
unset_case_analysis [get_ports rst_n]
puts "RESET_VISIBLE_SLEW [sta::max_slew_violation_count]"
puts "RESET_VISIBLE_CAP [sta::max_capacitance_violation_count]"
set_case_analysis 1 [get_ports rst_n]

write_db $cand/butterfold_top_co6a27b.odb
write_def $cand/butterfold_top_co6a27b.def
write_verilog -include_pwr_gnd $cand/butterfold_top.co6a27b.pnl.v
puts "CO6A27B_DONE"
exit
