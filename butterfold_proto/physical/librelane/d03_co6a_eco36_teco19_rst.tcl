# teco19: buffer ONLY rst_n (1460 sinks, no driver). All other cells/nets dont_touch.
# Abort if repair_design inserts >120 new cells. Do not full-reroute.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
set pdk /foss/pdks/gf180mcuD
set src $proto/physical/results/d03_ach_candidate/co6a36/setup_eco22/butterfold_top_co6a36_teco18.odb
set outdir $proto/physical/results/d03_ach_candidate/co6a36/setup_eco23
file mkdir $outdir
puts "ECO_SRC $src"

read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/techlef/gf180mcu_fd_sc_mcu9t5v0__nom.tlef
read_lef $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lef/gf180mcu_fd_sc_mcu9t5v0.lef
read_lef $pdk/libs.ref/gf180mcu_fd_ip_sram/lef/gf180mcu_fd_ip_sram__sram256x8m8wm1.lef
read_liberty $pdk/libs.ref/gf180mcu_fd_sc_mcu9t5v0/lib/gf180mcu_fd_sc_mcu9t5v0__ss_125C_4v50.lib
read_liberty $pdk/libs.ref/gf180mcu_fd_ip_sram/lib/gf180mcu_fd_ip_sram__sram256x8m8wm1__ss_125C_4v50.lib
read_db $src
read_sdc $proto/physical/constraints.sdc
set_propagated_clock [get_clocks core_clk]
set_dont_use {gf180mcu_fd_sc_mcu9t5v0__bufz_* gf180mcu_fd_sc_mcu9t5v0__antenna gf180mcu_fd_sc_mcu9t5v0__hold gf180mcu_fd_sc_mcu9t5v0__dlya_* gf180mcu_fd_sc_mcu9t5v0__dlyb_* gf180mcu_fd_sc_mcu9t5v0__dlyc_* gf180mcu_fd_sc_mcu9t5v0__dlyd_*}
# keep clkbuf available for rst_n tree only
set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
set_wire_rc -signal -layer Metal2
set_wire_rc -clock -layer Metal4
catch {set_thread_count 22}

set nine {_11280_ _11106_ _11366_ _11339_ _11136_ _11474_ _11394_ _11408_ _11241_}
set db [ord::get_db]
set block [ord::get_db_block]
set dbu [[ord::get_db_tech] getDbUnitsPerMicron]
set n0 [llength [$block getInsts]]
puts "INST0 $n0"

foreach inst [$block getInsts] { $inst setPlacementStatus FIRM }

# Port rst_n drives 1460 sinks with no stdcell driver. Insert one root clkbuf_16
# near the west pin so repair_design has a cell-driven net to split.
set c16 [$db findMaster gf180mcu_fd_sc_mcu9t5v0__clkbuf_16]
set rst [$block findNet rst_n]
set mid [odb::dbNet_create $block rst_n_buf]
set sinks {}
foreach it [$rst getITerms] { lappend sinks $it }
puts "MOVE_SINKS [llength $sinks]"
foreach it $sinks {
  odb::dbITerm_disconnect $it
  odb::dbITerm_connect $it $mid
}
set buf [odb::dbInst_create $block $c16 teco19_rst_root]
$buf setOrient R0
# CORE left ~6.72; pin y~273.76; site 5.04 -> row 272.16
$buf setLocation [expr {int(11.2*$dbu)}] [expr {int(272.16*$dbu)}]
$buf setPlacementStatus PLACED
odb::dbITerm_connect [$buf findITerm I] $rst
odb::dbITerm_connect [$buf findITerm Z] $mid
puts "ROOT [[$buf getMaster] getName] loc=11.2 272.16 rst_terms=[llength [$rst getITerms]] mid_terms=[llength [$mid getITerms]]"

# Freeze clock tree / nine AOI so repair cannot resize them.
foreach inst [$block getInsts] {
  if {$inst eq $buf} continue
  set n [$inst getName]
  set m [[$inst getMaster] getName]
  if {[string match "*clkbuf*" $m] || [string match "*clkload*" $n] || \
      [string match "teco*_sk*" $n] || [lsearch -exact $nine $n] >= 0} {
    catch {set_dont_touch [get_cells $n]}
  }
}
set_dont_touch [get_nets *]
catch {unset_dont_touch [get_nets rst_n_buf]}
# SDC holds rst_n as constant 1; repair_design skips constant nets.
unset_case_analysis [get_ports rst_n]
catch {estimate_parasitics -placement}
puts "REPAIR_RST_ONLY"
if {[catch {repair_design -verbose} msg]} {
  puts "REPAIR_WARN $msg"
}
set n1 [llength [$block getInsts]]
puts "INST1 $n1 NEW [expr {$n1-$n0}]"
set news {}
foreach inst [$block getInsts] {
  if {[$inst getPlacementStatus] ne "FIRM"} {
    lappend news [$inst getName]
    puts "NEW [$inst getName] [[$inst getMaster] getName] [$inst getOrient] status=[$inst getPlacementStatus]"
  }
}
puts "NEW_COUNT [llength $news]"
if {[llength $news] > 120} {
  puts "ABORT too many new cells"; exit 1
}

foreach name $nine {
  set i [$block findInst $name]
  if {[[$i getMaster] getName] ne "gf180mcu_fd_sc_mcu9t5v0__aoi221_2" || [$i getOrient] ne "R180"} {
    puts "CELL_LOST $name [[$i getMaster] getName] [$i getOrient]"; exit 1
  }
}

# rst_n connectivity after repair
set n [$block findNet rst_n]
puts "RST_N terms=[llength [$n getITerms]]"
set ndrv 0
foreach it [$n getITerms] {
  if {[[$it getMTerm] getIoType] eq "OUTPUT"} {
    incr ndrv
    puts "RST_DRV [[$it getInst] getName]/[[$it getMTerm] getName] [[[$it getInst] getMaster] getName]"
  }
}
puts "RST_NDRV $ndrv"
write_db $outdir/butterfold_top_co6a36_teco19_preroute.odb
puts "TECO19_DRY_DONE"
exit
