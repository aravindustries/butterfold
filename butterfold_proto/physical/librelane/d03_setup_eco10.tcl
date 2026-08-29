# ECO10: last ~1.08 ns is depth+_4 load, not weak _1 cells.
# Buffer high-fanout ZN nets on the shared _18692_ path; upsize the
# tail buf_4 chain; clone load_slew111 (FO 33); fix electrical oai211_1.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set eco $proto/physical/results/d03_ach_setup_eco
set out $proto/physical/reports/signoff/evidence/d03_ach/setup

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $eco/butterfold_top_eco9_routed.odb
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_dont_use {gf180mcu_fd_sc_mcu9t5v0__bufz_* gf180mcu_fd_sc_mcu9t5v0__antenna gf180mcu_fd_sc_mcu9t5v0__hold gf180mcu_fd_sc_mcu9t5v0__dlya_* gf180mcu_fd_sc_mcu9t5v0__dlyb_*}
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4

set db [ord::get_db]
set block [ord::get_db_block]

proc eco_swap {block db inst tgt} {
  set i [$block findInst $inst]
  if {$i eq "NULL" || $i eq ""} { puts "NOINST $inst"; return 0 }
  set m [$db findMaster $tgt]
  if {$m eq "NULL" || $m eq ""} { puts "NOMASTER $tgt have [[$i getMaster] getName]"; return 0 }
  if {[catch {$i swapMaster $m} msg]} { puts "SWAP_FAIL $inst $msg"; return 0 }
  puts "SWAP $inst -> $tgt"
  return 1
}
eco_swap $block $db wire33 gf180mcu_fd_sc_mcu9t5v0__clkbuf_16
eco_swap $block $db fanout249 gf180mcu_fd_sc_mcu9t5v0__clkbuf_16
eco_swap $block $db max_cap32 gf180mcu_fd_sc_mcu9t5v0__clkbuf_16
eco_swap $block $db _16946_ gf180mcu_fd_sc_mcu9t5v0__mux2_4
eco_swap $block $db _11576_ gf180mcu_fd_sc_mcu9t5v0__oai211_4

proc eco_insert_buf {block db instname pin mastername bufname} {
  set inst [$block findInst $instname]
  if {$inst eq "NULL" || $inst eq ""} { puts "NOINST_BUF $instname"; return 0 }
  if {[$block findInst $bufname] ne "NULL" && [$block findInst $bufname] ne ""} { return 0 }
  set iterm [$inst findITerm $pin]
  if {$iterm eq "NULL" || $iterm eq ""} { puts "NOTERM $instname/$pin"; return 0 }
  set oldnet [$iterm getNet]
  if {$oldnet eq "NULL" || $oldnet eq ""} { return 0 }
  set master [$db findMaster $mastername]
  if {$master eq "NULL" || $master eq ""} { return 0 }
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
  puts "INSERTED $bufname after $instname/$pin FO_was_net [$oldnet getName]"
  return 1
}
set c16 gf180mcu_fd_sc_mcu9t5v0__clkbuf_16
eco_insert_buf $block $db _15936_ ZN $c16 eco10_buf_15936
eco_insert_buf $block $db _15970_ ZN $c16 eco10_buf_15970
eco_insert_buf $block $db _09742_ ZN $c16 eco10_buf_09742

# Clone load_slew111: split net111 (~33 terms) across two clkbuf_16.
set src [$block findInst load_slew111]
if {$src ne "NULL" && $src ne ""} {
  set z [$src findITerm Z]
  set n [$z getNet]
  set loads {}
  foreach it [$n getITerms] {
    set iname [[$it getInst] getName]
    set pn [[$it getMTerm] getName]
    if {$iname eq "load_slew111" && $pn eq "Z"} { continue }
    lappend loads $it
  }
  set nload [llength $loads]
  puts "LOAD_SLEW111_LOADS $nload"
  set clone [odb::dbInst_create $block [$db findMaster $c16] load_slew111_b]
  lassign [$src getLocation] x y
  $clone setOrient R0
  $clone setLocation [expr {$x + 4480}] $y
  $clone setPlacementStatus PLACED
  set innet [[$src findITerm I] getNet]
  odb::dbITerm_connect [$clone findITerm I] $innet
  set n2 [odb::dbNet_create $block net111_b]
  odb::dbITerm_connect [$clone findITerm Z] $n2
  set i 0
  foreach it $loads {
    if {$i % 2 == 1} {
      odb::dbITerm_disconnect $it
      odb::dbITerm_connect $it $n2
    }
    incr i
  }
  puts "CLONED load_slew111_b moved [expr {$nload / 2}] loads"
}

set_placement_padding -global -left 2 -right 2
if {[catch {detailed_placement -max_displacement {800 200}} msg]} {
  puts "LEGALIZE_WARN $msg"
}
if {[catch {check_placement -verbose} cmsg]} { puts "CHECK_PLACEMENT $cmsg" } else { puts "CHECK_PLACEMENT_OK" }

puts "ECO10_REROUTE"
foreach net [$block getNets] {
  set st [$net getSigType]
  if {[string match *POWER* $st] || [string match *GROUND* $st]} { continue }
  if {[$net getWire] ne "" && [$net getWire] ne "NULL"} {
    catch {odb::dbWire_destroy [$net getWire]}
  }
  catch {$net clearGuides}
}
foreach layer {Metal2 Metal3 Metal4 Metal5} {
  set_global_routing_layer_adjustment $layer 0.3
}
catch {global_connect}
global_route -congestion_iterations 50 -verbose -guide_file $eco/eco10.guide
detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc $eco/eco10.drc
write_db $eco/butterfold_top_eco10_routed.odb
write_def $eco/butterfold_top_eco10_routed.def

set rcx_max $pdk/libs.tech/librelane/rules.openrcx.gf180mcuD.max
if {[catch {
  extract_parasitics -ext_model_file $rcx_max
  write_spef $eco/eco10.max.spef
  read_spef $eco/eco10.max.spef
} emsg]} { puts "EXTRACT_WARN $emsg" }
puts "ECO10_EXTRACTED_WNS"
report_wns -max
report_tns -max
catch {report_wns -max > $out/eco10_spef_wns.rpt}
catch {report_tns -max > $out/eco10_spef_tns.rpt}
catch {report_checks -path_delay max -slack_max 0 -group_path_count 40 > $out/eco10_spef_violations.rpt}
catch {report_check_types -max_slew -max_cap -max_fanout -violators > $out/eco10_spef_electrical.rpt}
puts "ECO10_COMPLETE"
exit
