# Destroy DRT-1010 non-ortho wires then GRT/DRT the 18 buffer nets + those 5.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set cand $proto/physical/results/d03_ach_candidate
set eco $proto/physical/results/d03_ach_setup_eco
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $cand/butterfold_top_co6a27b.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
set block [ord::get_db_block]
set kill {dout[3] dout[4] dout[5] u_transform_scheduler_core.u_fft_scratch_sram.u_lo.macro_wdata[3] u_transform_scheduler_core.u_fft_scratch_sram.u_hi.macro_wdata[2]}
foreach nn $kill {
    set n [$block findNet $nn]
    if {$n eq "NULL"} { puts "MISSING $nn"; continue }
    if {[$n getWire] ne "" && [$n getWire] ne "NULL"} { catch {odb::dbWire_destroy [$n getWire]} }
    catch {$n clearGuides}
    puts "RIP_NONORTHO $nn"
}
foreach layer {Metal2 Metal3 Metal4 Metal5} { set_global_routing_layer_adjustment $layer 0.3 }
if {[catch {global_route -congestion_iterations 30 -verbose} gmsg]} { puts "GRT_WARN $gmsg" }
if {[catch {detailed_route -droute_end_iter 32 -or_seed 42 -verbose 1 -output_drc $eco/co6a27d.drc} dmsg]} {
    puts "DRT_WARN $dmsg"
} else { puts "DRT_OK" }
puts "ANT"; catch {check_antennas}
puts "PG_VDD"; if {[catch {check_power_grid -net VDD} e]} { puts "VDD_ERR $e" } else { puts "VDD_OK" }
puts "PG_VSS"; if {[catch {check_power_grid -net VSS} e]} { puts "VSS_ERR $e" } else { puts "VSS_OK" }
extract_parasitics -ext_model_file $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
write_spef $cand/co6a27d.max.spef
read_spef $cand/co6a27d.max.spef
puts "SETUP_WNS"; report_wns -max
puts "SETUP_TNS"; report_tns -max
puts "ELEC"; report_check_types -max_slew -max_cap -max_fanout -violators
write_db $cand/butterfold_top_co6a27d.odb
write_def $cand/butterfold_top_co6a27d.def
puts "CO6A27D_DONE"
exit
