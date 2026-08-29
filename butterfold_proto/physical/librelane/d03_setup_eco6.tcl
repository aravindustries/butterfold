# ECO6: class resize of remaining extracted-path _1/_2 cells (mux2_1
# army, weak control, dlya/clkbuf_2, startpoint FFs). Preserve CLOCK.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_setup_eco
set out $proto/physical/reports/signoff/evidence/d03_ach/setup

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $eco/butterfold_top_eco5_routed.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_dont_use {gf180mcu_fd_sc_mcu9t5v0__bufz_* gf180mcu_fd_sc_mcu9t5v0__antenna gf180mcu_fd_sc_mcu9t5v0__hold gf180mcu_fd_sc_mcu9t5v0__dlya_* gf180mcu_fd_sc_mcu9t5v0__dlyb_*}
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4

set db [ord::get_db]
set block [ord::get_db_block]
set nswap 0
set fh [open $eco/eco6_swaps.txt r]
while {[gets $fh line] >= 0} {
  if {[string trim $line] eq ""} { continue }
  lassign $line inst src tgt
  set i [$block findInst $inst]
  if {$i eq "NULL" || $i eq ""} { puts "NOINST $inst"; continue }
  set m [$db findMaster $tgt]
  if {$m eq "NULL" || $m eq ""} { puts "NOMASTER $tgt"; continue }
  if {[catch {$i swapMaster $m} msg]} { puts "SWAP_FAIL $inst $msg" } else { incr nswap }
}
close $fh
puts "ECO6_SWAPPED $nswap"

foreach name {_12495_ _12028_} {
  set i [$block findInst $name]
  if {$i eq "NULL" || $i eq ""} { continue }
  set mn [[$i getMaster] getName]
  puts "ELEC $name $mn"
  if {[regexp {^(gf180mcu_fd_sc_mcu9t5v0__.+_)([12])$} $mn -> stem stren]} {
    set tgt ${stem}4
    set m [$db findMaster $tgt]
    if {$m ne "NULL" && $m ne ""} {
      if {[catch {$i swapMaster $m} msg]} { puts "ELEC_SWAP_FAIL $name $msg" } else { puts "ELEC_SWAP $name -> $tgt" }
    }
  }
}

set buf8 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__buf_8]
set nsram 0
foreach inst [$block getInsts] {
  set n [$inst getName]
  if {[string match "*g_pin_drive*" $n] && [string match "*u_*_driver*" $n]} {
    set mn [[$inst getMaster] getName]
    if {[string match "*__buf_*" $mn] && $mn ne "gf180mcu_fd_sc_mcu9t5v0__buf_8" && $mn ne "gf180mcu_fd_sc_mcu9t5v0__buf_16" && $buf8 ne "NULL"} {
      if {[catch {$inst swapMaster $buf8} msg]} { puts "SRAM_DRV_FAIL $n $msg" } else { incr nsram }
    }
  }
}
puts "ECO6_SRAM_DRV $nsram"

proc eco_insert_buf {block db instname pin mastername bufname} {
  set inst [$block findInst $instname]
  if {$inst eq "NULL" || $inst eq ""} { puts "NOINST_BUF $instname"; return 0 }
  if {[$block findInst $bufname] ne "NULL" && [$block findInst $bufname] ne ""} {
    puts "BUF_EXISTS $bufname"; return 0
  }
  set iterm [$inst findITerm $pin]
  if {$iterm eq "NULL" || $iterm eq ""} { puts "NOTERM $instname/$pin"; return 0 }
  set oldnet [$iterm getNet]
  if {$oldnet eq "NULL" || $oldnet eq ""} { puts "NONET $instname/$pin"; return 0 }
  set master [$db findMaster $mastername]
  if {$master eq "NULL" || $master eq ""} { puts "NOMASTER_BUF $mastername"; return 0 }
  set mid [odb::dbNet_create $block ${bufname}_i]
  set buf [odb::dbInst_create $block $master $bufname]
  lassign [$inst getLocation] x y
  $buf setOrient R0
  $buf setLocation [expr {$x + 2240}] $y
  $buf setPlacementStatus PLACED
  odb::dbITerm_disconnect $iterm
  odb::dbITerm_connect $iterm $mid
  odb::dbITerm_connect [$buf findITerm I] $mid
  odb::dbITerm_connect [$buf findITerm Z] $oldnet
  puts "INSERTED $bufname after $instname/$pin on [$oldnet getName]"
  return 1
}
eco_insert_buf $block $db _11548_ ZN gf180mcu_fd_sc_mcu9t5v0__clkbuf_16 eco6_buf_11548
eco_insert_buf $block $db _15979_ ZN gf180mcu_fd_sc_mcu9t5v0__clkbuf_16 eco6_buf_15979
eco_insert_buf $block $db _09848_ ZN gf180mcu_fd_sc_mcu9t5v0__clkbuf_16 eco6_buf_09848
eco_insert_buf $block $db _10314_ ZN gf180mcu_fd_sc_mcu9t5v0__clkbuf_16 eco6_buf_10314
eco_insert_buf $block $db _11983_ ZN gf180mcu_fd_sc_mcu9t5v0__clkbuf_16 eco6_buf_11983

set_placement_padding -global -left 2 -right 2
if {[catch {detailed_placement -max_displacement {800 200}} msg]} {
  puts "LEGALIZE_WARN $msg"
}
if {[catch {check_placement -verbose} cmsg]} { puts "CHECK_PLACEMENT $cmsg" } else { puts "CHECK_PLACEMENT_OK" }

puts "ECO6_REROUTE"
foreach net [$block getNets] {
  set st [$net getSigType]
  if {[string match *POWER* $st] || [string match *GROUND* $st] || [string match *CLOCK* $st]} { continue }
  if {[$net getWire] ne "" && [$net getWire] ne "NULL"} {
    catch {odb::dbWire_destroy [$net getWire]}
  }
  catch {$net clearGuides}
}
foreach layer {Metal2 Metal3 Metal4 Metal5} {
  set_global_routing_layer_adjustment $layer 0.3
}
catch {global_connect}
global_route -congestion_iterations 50 -verbose -guide_file $eco/eco6.guide
detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $eco/eco6.drc
write_db $eco/butterfold_top_eco6_routed.odb
write_def $eco/butterfold_top_eco6_routed.def

set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
if {[catch {
  extract_parasitics -ext_model_file $rcx_max
  write_spef $eco/eco6.max.spef
  read_spef $eco/eco6.max.spef
} emsg]} { puts "EXTRACT_WARN $emsg" }
puts "ECO6_EXTRACTED_WNS"
report_wns -max
report_tns -max
catch {report_wns -max > $out/eco6_spef_wns.rpt}
catch {report_tns -max > $out/eco6_spef_tns.rpt}
catch {report_checks -path_delay max -slack_max 0 -group_path_count 40 > $out/eco6_spef_violations.rpt}
catch {report_check_types -max_slew -max_cap -max_fanout -violators > $out/eco6_spef_electrical.rpt}
puts "ECO6_COMPLETE"
exit
