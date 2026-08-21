# =============================================================================
# ButterFold post-route extracted-aware setup-closure ECO
# =============================================================================
#
# Production operating point:
#   core clock          = 38.4 MHz
#   period              = 26.041667 ns
#   TX_BYTE_INTERVAL    = 10
#   target STA corner   = max_ss_125C_4v50 (GF180 9T, SS 125 C, 4.50 V)
#
# Why this script exists:
#   LibreLane 3.0.2 already ran post-GRT repair_design / resizer timing
#   (RUN_POST_GRT_DESIGN_REPAIR, RUN_POST_GRT_RESIZER_TIMING). Those passes
#   see optimistic global-route RC. Final OpenRCX extraction inflated cell
#   delay through slow-corner Liberty (slew/load), producing:
#       setup WNS = -9.511 ns   TNS = -3307 ns   763 violations
#   There is no SPEF/Liberty unit mismatch; this is a correlation problem.
#
#   The operations below are the post-route extracted-aware ECO that closed
#   max-SS setup at 38.4 MHz. They are NOT produced by the tracked LibreLane
#   config and must be applied to the production post-DRT ODB.
#
# Starting checkpoint (tracked):
#   physical/librelane/runs/butterfold_top_38p4_interval10_production_9t/
#     46-odb-reportdisconnectedpins/butterfold_top.odb
#   That database is the clean interval-10 production implementation AFTER
#   detailed routing / antenna diodes / disconnected-pin check and BEFORE
#   filler insertion. LibreLane post-GRT repair is already in it.
#
# This script does not:
#   - rerun synthesis, floorplan, placement, or CTS
#   - rerun repair_design / repair_timing
#   - change RTL, goldens, SDC, or CLOCK_PERIOD
#   - lower the clock
#   - touch the seven production antenna diode instances
#   - resize CTS cells
#
# Default: apply logical ECO + incremental legalization and write ODB/DEF.
# Optional: ECO_ROUTE=1 also clears ordinary dbWires (preserving PDN/CTS NDR)
#           then runs one GRT + one DRT. That is the proven post-ECO route
#           method; it is off by default so this file can be committed without
#           invoking TritonRoute.
#
# Usage (from butterfold_proto):
#   openroad -no_init -exit physical/scripts/postroute_setup_close.tcl
#
# Optional environment:
#   ECO_SRC     production post-DRT ODB
#   ECO_OUTDIR  directory for written ODB/DEF
#   ECO_ROUTE   0 (default) or 1
#
# Closed reference (workspace copy, gitignored under physical/results/):
#   physical/results/38p4_setup_closed/iter2_routed.odb
#   SHA-256 073bcd1b1029fdb8d7a3914cd65b43709a53ad2f7c76e83bfbce20ba9bfa1e64
#   extracted max-SS: WNS +0.177954 ns  TNS 0  violations 0
#                     hold WNS +0.559095 ns
# =============================================================================

set script_dir [file dirname [file normalize [info script]]]
set proto_root [file normalize [file join $script_dir .. ..]]
if {![info exists env(ECO_SRC)] || $env(ECO_SRC) eq ""} {
  set src [file join $proto_root physical/librelane/runs/butterfold_top_38p4_interval10_production_9t/46-odb-reportdisconnectedpins/butterfold_top.odb]
} else {
  set src $env(ECO_SRC)
}
if {![info exists env(ECO_OUTDIR)] || $env(ECO_OUTDIR) eq ""} {
  set outdir [file join $proto_root physical/results/38p4_setup_closed/eco_replay]
} else {
  set outdir $env(ECO_OUTDIR)
}
set do_route 0
if {[info exists env(ECO_ROUTE)] && $env(ECO_ROUTE) eq "1"} { set do_route 1 }
file mkdir $outdir
puts "ECO_SRC $src"
puts "ECO_OUTDIR $outdir"
if {![file exists $src]} { puts "ERROR missing source ODB $src"; exit 1 }
read_db $src
set db [ord::get_db]
set block [ord::get_db_block]

proc eco_must_inst {name} {
  set inst [[ord::get_db_block] findInst $name]
  if {$inst eq "" || $inst eq "NULL"} { error "missing instance $name" }
  return $inst
}
proc eco_must_net {name} {
  set net [[ord::get_db_block] findNet $name]
  if {$net eq "" || $net eq "NULL"} { error "missing net $name" }
  return $net
}
proc eco_must_master {name} {
  set m [[ord::get_db] findMaster $name]
  if {$m eq "" || $m eq "NULL"} { error "missing master $name" }
  return $m
}
proc eco_connect {inst_name pin net_name} {
  set inst [eco_must_inst $inst_name]
  set iterm [$inst findITerm $pin]
  if {$iterm eq "" || $iterm eq "NULL"} { error "missing pin $inst_name/$pin" }
  set net [eco_must_net $net_name]
  if {[$iterm getNet] ne "" && [$iterm getNet] ne "NULL"} {
    odb::dbITerm_disconnect $iterm
  }
  odb::dbITerm_connect $iterm $net
}

puts "ECO_BEGIN prod_insts [llength [$block getInsts]]"

# Preserve production antenna diodes through legalization.
foreach inst [$block getInsts] {
  set m [[$inst getMaster] getName]
  if {[string match "*__antenna" $m]} {
    $inst setDoNotTouch 1
    $inst setPlacementStatus FIRM
  }
}

# ----- 19 new nets for extracted-aware buffers/clones -----
puts "ECO_CREATE_NETS 19"
set nobj [odb::dbNet_create $block {net}]
if {$nobj eq "" || $nobj eq "NULL"} { error "failed to create net net" }
set nobj [odb::dbNet_create $block {net225}]
if {$nobj eq "" || $nobj eq "NULL"} { error "failed to create net net225" }
set nobj [odb::dbNet_create $block {net226}]
if {$nobj eq "" || $nobj eq "NULL"} { error "failed to create net net226" }
set nobj [odb::dbNet_create $block {net227}]
if {$nobj eq "" || $nobj eq "NULL"} { error "failed to create net net227" }
set nobj [odb::dbNet_create $block {net228}]
if {$nobj eq "" || $nobj eq "NULL"} { error "failed to create net net228" }
set nobj [odb::dbNet_create $block {net229}]
if {$nobj eq "" || $nobj eq "NULL"} { error "failed to create net net229" }
set nobj [odb::dbNet_create $block {net230}]
if {$nobj eq "" || $nobj eq "NULL"} { error "failed to create net net230" }
set nobj [odb::dbNet_create $block {net231}]
if {$nobj eq "" || $nobj eq "NULL"} { error "failed to create net net231" }
set nobj [odb::dbNet_create $block {net232}]
if {$nobj eq "" || $nobj eq "NULL"} { error "failed to create net net232" }
set nobj [odb::dbNet_create $block {net233}]
if {$nobj eq "" || $nobj eq "NULL"} { error "failed to create net net233" }
set nobj [odb::dbNet_create $block {net234}]
if {$nobj eq "" || $nobj eq "NULL"} { error "failed to create net net234" }
set nobj [odb::dbNet_create $block {net235}]
if {$nobj eq "" || $nobj eq "NULL"} { error "failed to create net net235" }
set nobj [odb::dbNet_create $block {net236}]
if {$nobj eq "" || $nobj eq "NULL"} { error "failed to create net net236" }
set nobj [odb::dbNet_create $block {net237}]
if {$nobj eq "" || $nobj eq "NULL"} { error "failed to create net net237" }
set nobj [odb::dbNet_create $block {net238}]
if {$nobj eq "" || $nobj eq "NULL"} { error "failed to create net net238" }
set nobj [odb::dbNet_create $block {net239}]
if {$nobj eq "" || $nobj eq "NULL"} { error "failed to create net net239" }
set nobj [odb::dbNet_create $block {net240}]
if {$nobj eq "" || $nobj eq "NULL"} { error "failed to create net net240" }
set nobj [odb::dbNet_create $block {net242}]
if {$nobj eq "" || $nobj eq "NULL"} { error "failed to create net net242" }
set nobj [odb::dbNet_create $block {net243}]
if {$nobj eq "" || $nobj eq "NULL"} { error "failed to create net net243" }

# ----- 19 inserted instances (8 clones, 10 load/wire buffers, 1 split) -----
puts "ECO_CREATE_INSTS 19"
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nand4_2}]
set inst [odb::dbInst_create $block $master {clone235}]
$inst setOrient MX
$inst setLocation 1429120 1038240
$inst setPlacementStatus PLACED
eco_connect {clone235} {A1} {_04357_}
eco_connect {clone235} {A2} {_04056_}
eco_connect {clone235} {A3} {_04487_}
eco_connect {clone235} {A4} {u_transform_scheduler_core.rx_state\[14\]}
eco_connect {clone235} {ZN} {net235}

set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi21_2}]
set inst [odb::dbInst_create $block $master {clone236}]
$inst setOrient R0
$inst setLocation 1734880 987840
$inst setPlacementStatus PLACED
eco_connect {clone236} {A1} {_02497_}
eco_connect {clone236} {A2} {_02701_}
eco_connect {clone236} {B} {_02699_}
eco_connect {clone236} {ZN} {net236}

set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi21_2}]
set inst [odb::dbInst_create $block $master {clone237}]
$inst setOrient MX
$inst setLocation 2027200 1764000
$inst setPlacementStatus PLACED
eco_connect {clone237} {A1} {_04620_}
eco_connect {clone237} {A2} {_04499_}
eco_connect {clone237} {B} {_04339_}
eco_connect {clone237} {ZN} {net237}

set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai31_2}]
set inst [odb::dbInst_create $block $master {clone238}]
$inst setOrient MX
$inst setLocation 1468320 1179360
$inst setPlacementStatus PLACED
eco_connect {clone238} {A1} {_04356_}
eco_connect {clone238} {A2} {_03895_}
eco_connect {clone238} {A3} {_04488_}
eco_connect {clone238} {B} {_04056_}
eco_connect {clone238} {ZN} {net238}

set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai21_2}]
set inst [odb::dbInst_create $block $master {clone239}]
$inst setOrient MX
$inst setLocation 1772960 957600
$inst setPlacementStatus PLACED
eco_connect {clone239} {A1} {_02772_}
eco_connect {clone239} {A2} {_02510_}
eco_connect {clone239} {B} {_02770_}
eco_connect {clone239} {ZN} {net239}

set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nand4_2}]
set inst [odb::dbInst_create $block $master {clone240}]
$inst setOrient R0
$inst setLocation 1589280 1189440
$inst setPlacementStatus PLACED
eco_connect {clone240} {A1} {_04357_}
eco_connect {clone240} {A2} {_04056_}
eco_connect {clone240} {A3} {_04487_}
eco_connect {clone240} {A4} {u_transform_scheduler_core.rx_state\[14\]}
eco_connect {clone240} {ZN} {net240}

set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__and4_2}]
set inst [odb::dbInst_create $block $master {clone242}]
$inst setOrient R0
$inst setLocation 1942080 1008000
$inst setPlacementStatus PLACED
eco_connect {clone242} {A1} {_02521_}
eco_connect {clone242} {A2} {_02523_}
eco_connect {clone242} {A3} {_02526_}
eco_connect {clone242} {A4} {_02847_}
eco_connect {clone242} {Z} {net242}

set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nand2_2}]
set inst [odb::dbInst_create $block $master {clone243}]
$inst setOrient R0
$inst setLocation 1836800 524160
$inst setPlacementStatus PLACED
eco_connect {clone243} {A1} {_02531_}
eco_connect {clone243} {A2} {_02512_}
eco_connect {clone243} {ZN} {net243}

set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__clkbuf_4}]
set inst [odb::dbInst_create $block $master {load_slew225}]
$inst setOrient MX
$inst setLocation 389760 957600
$inst setPlacementStatus PLACED
eco_connect {load_slew225} {I} {_04287_}
eco_connect {load_slew225} {Z} {net225}

set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__clkbuf_16}]
set inst [odb::dbInst_create $block $master {load_slew228}]
$inst setOrient MX
$inst setLocation 1522080 977760
$inst setPlacementStatus PLACED
eco_connect {load_slew228} {I} {_05678_}
eco_connect {load_slew228} {Z} {net228}

set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__clkbuf_2}]
set inst [odb::dbInst_create $block $master {load_slew229}]
$inst setOrient R0
$inst setLocation 389760 1108800
$inst setPlacementStatus PLACED
eco_connect {load_slew229} {I} {_04285_}
eco_connect {load_slew229} {Z} {net229}

set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__clkbuf_4}]
set inst [odb::dbInst_create $block $master {load_slew230}]
$inst setOrient R0
$inst setLocation 1473920 1068480
$inst setPlacementStatus PLACED
eco_connect {load_slew230} {I} {_05686_}
eco_connect {load_slew230} {Z} {net230}

set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__clkbuf_12}]
set inst [odb::dbInst_create $block $master {load_slew231}]
$inst setOrient R0
$inst setLocation 1858080 1048320
$inst setPlacementStatus PLACED
eco_connect {load_slew231} {I} {_06112_}
eco_connect {load_slew231} {Z} {net231}

set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__clkbuf_8}]
set inst [odb::dbInst_create $block $master {load_slew232}]
$inst setOrient R0
$inst setLocation 1747200 1108800
$inst setPlacementStatus PLACED
eco_connect {load_slew232} {I} {_06111_}
eco_connect {load_slew232} {Z} {net232}

set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__buf_4}]
set inst [odb::dbInst_create $block $master {load_slew233}]
$inst setOrient R0
$inst setLocation 1281280 1370880
$inst setPlacementStatus PLACED
eco_connect {load_slew233} {I} {_04454_}
eco_connect {load_slew233} {Z} {net233}

set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__clkbuf_8}]
set inst [odb::dbInst_create $block $master {load_slew234}]
$inst setOrient MX
$inst setLocation 2041760 1764000
$inst setPlacementStatus PLACED
eco_connect {load_slew234} {I} {u_transform_scheduler_core.tx_mapper_busy}
eco_connect {load_slew234} {Z} {net234}

set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__buf_2}]
set inst [odb::dbInst_create $block $master {split}]
$inst setOrient R0
$inst setLocation 1152480 1350720
$inst setPlacementStatus PLACED
eco_connect {split} {I} {u_transform_scheduler_core.fft128_active}
eco_connect {split} {Z} {net}

set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__clkbuf_2}]
set inst [odb::dbInst_create $block $master {wire226}]
$inst setOrient MX
$inst setLocation 1884960 171360
$inst setPlacementStatus PLACED
eco_connect {wire226} {I} {_06962_}
eco_connect {wire226} {Z} {net226}

set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__clkbuf_2}]
set inst [odb::dbInst_create $block $master {wire227}]
$inst setOrient MX
$inst setLocation 1932000 997920
$inst setPlacementStatus PLACED
eco_connect {wire227} {I} {_06638_}
eco_connect {wire227} {Z} {net227}

# ----- retarget existing sinks onto the new (or swapped) nets -----
puts "ECO_SINK_MOVES 178"
eco_connect {_09470_} {I} {net229}
eco_connect {_09472_} {B} {net229}
eco_connect {_09473_} {B} {net229}
eco_connect {_09617_} {B} {net}
eco_connect {_09890_} {A1} {net}
eco_connect {_09989_} {A1} {net}
eco_connect {_10002_} {A1} {net}
eco_connect {_10003_} {A1} {net}
eco_connect {_10043_} {A1} {net}
eco_connect {_10060_} {A1} {net}
eco_connect {_10107_} {B2} {net}
eco_connect {_10127_} {A1} {net}
eco_connect {_10140_} {A1} {net}
eco_connect {_10244_} {A1} {net234}
eco_connect {_10424_} {B} {net234}
eco_connect {_10668_} {B2} {net237}
eco_connect {_10704_} {B2} {net237}
eco_connect {_10750_} {B2} {net237}
eco_connect {_10775_} {B2} {net237}
eco_connect {_10796_} {B2} {net237}
eco_connect {_11110_} {S} {net228}
eco_connect {_11112_} {A2} {net228}
eco_connect {_11156_} {A2} {net228}
eco_connect {_11161_} {S} {net228}
eco_connect {_11251_} {A2} {net228}
eco_connect {_11252_} {A2} {net228}
eco_connect {_11261_} {S0} {net228}
eco_connect {_11262_} {A2} {net228}
eco_connect {_11313_} {S0} {net228}
eco_connect {_11314_} {A2} {net228}
eco_connect {_11403_} {S} {net228}
eco_connect {_11413_} {A2} {net228}
eco_connect {_11415_} {S0} {net228}
eco_connect {_11417_} {A2} {net228}
eco_connect {_11444_} {A2} {net228}
eco_connect {_11451_} {A2} {net228}
eco_connect {_11455_} {S0} {net228}
eco_connect {_11457_} {A2} {net228}
eco_connect {_11467_} {A2} {net228}
eco_connect {_11468_} {S0} {net228}
eco_connect {_11471_} {A2} {net228}
eco_connect {_11479_} {S} {net228}
eco_connect {_11497_} {S} {net228}
eco_connect {_11524_} {S} {net228}
eco_connect {_11562_} {A2} {net232}
eco_connect {_11571_} {A2} {net231}
eco_connect {_11572_} {A2} {net232}
eco_connect {_11710_} {A2} {net232}
eco_connect {_11711_} {A2} {net231}
eco_connect {_11712_} {A2} {net231}
eco_connect {_11713_} {A2} {net232}
eco_connect {_11733_} {A2} {net232}
eco_connect {_12037_} {A2} {net232}
eco_connect {_12041_} {A2} {net232}
eco_connect {_12044_} {A2} {net232}
eco_connect {_12059_} {S} {net231}
eco_connect {_12060_} {A2} {net232}
eco_connect {_12061_} {A2} {net232}
eco_connect {_12063_} {A2} {net231}
eco_connect {_12064_} {A2} {net231}
eco_connect {_12065_} {A2} {net232}
eco_connect {_12067_} {A2} {net232}
eco_connect {_12081_} {A2} {net232}
eco_connect {_12089_} {A2} {net232}
eco_connect {_12092_} {A2} {net232}
eco_connect {_12095_} {B} {net227}
eco_connect {_12096_} {A3} {net227}
eco_connect {_12106_} {A3} {net227}
eco_connect {_12107_} {S} {net231}
eco_connect {_12109_} {A2} {net231}
eco_connect {_12110_} {A2} {net231}
eco_connect {_12113_} {A2} {net231}
eco_connect {_12133_} {S} {net231}
eco_connect {_12134_} {A2} {net231}
eco_connect {_12138_} {A2} {net231}
eco_connect {_12179_} {S0} {net231}
eco_connect {_12180_} {A2} {net231}
eco_connect {_12200_} {S} {net231}
eco_connect {_12202_} {A2} {net231}
eco_connect {_12204_} {A2} {net231}
eco_connect {_12263_} {A2} {net231}
eco_connect {_12264_} {A2} {net231}
eco_connect {_12267_} {S} {net231}
eco_connect {_12283_} {A2} {net231}
eco_connect {_12284_} {A2} {net231}
eco_connect {_12287_} {A2} {net231}
eco_connect {_12317_} {A2} {net231}
eco_connect {_12322_} {A2} {net231}
eco_connect {_12323_} {A2} {net231}
eco_connect {_12361_} {A2} {net230}
eco_connect {_12383_} {S} {net230}
eco_connect {_12391_} {A2} {net230}
eco_connect {_12443_} {A2} {net226}
eco_connect {_12525_} {A2} {net230}
eco_connect {_12727_} {A2} {net229}
eco_connect {_13669_} {A1} {net225}
eco_connect {_13689_} {A1} {net225}
eco_connect {_13703_} {B} {net225}
eco_connect {_13716_} {B2} {net225}
eco_connect {_14375_} {A2} {net225}
eco_connect {_14384_} {A2} {net225}
eco_connect {_14476_} {B} {net225}
eco_connect {_14492_} {B} {net225}
eco_connect {_15434_} {A1} {net234}
eco_connect {_15466_} {A1} {net234}
eco_connect {_15771_} {S} {net233}
eco_connect {_15772_} {S} {net233}
eco_connect {_15773_} {S} {net233}
eco_connect {_15774_} {S} {net233}
eco_connect {_15775_} {S} {net233}
eco_connect {_15777_} {S} {net233}
eco_connect {_15778_} {S} {net233}
eco_connect {_15779_} {S} {net233}
eco_connect {_15781_} {S} {net233}
eco_connect {_15782_} {S} {net233}
eco_connect {_15783_} {S} {net233}
eco_connect {_15784_} {S} {net233}
eco_connect {_15785_} {S} {net233}
eco_connect {_15786_} {S} {net233}
eco_connect {_15859_} {A1} {_02457_}
eco_connect {_15859_} {A2} {net238}
eco_connect {_15931_} {A1} {net238}
eco_connect {_15966_} {A2} {net238}
eco_connect {_15984_} {A1} {net238}
eco_connect {_15989_} {A3} {net238}
eco_connect {_16001_} {S} {net235}
eco_connect {_16007_} {S} {net235}
eco_connect {_16014_} {S} {net240}
eco_connect {_16019_} {S} {net243}
eco_connect {_16020_} {S} {net235}
eco_connect {_16028_} {S} {net240}
eco_connect {_16035_} {S} {net240}
eco_connect {_16041_} {S} {net240}
eco_connect {_16073_} {S} {net243}
eco_connect {_16079_} {S} {net243}
eco_connect {_16091_} {S} {net243}
eco_connect {_16205_} {S} {net236}
eco_connect {_16304_} {S} {net239}
eco_connect {_16306_} {S} {net239}
eco_connect {_16312_} {S} {net239}
eco_connect {_16517_} {S} {net242}
eco_connect {_16519_} {S} {net242}
eco_connect {_16563_} {S} {net235}
eco_connect {_16571_} {A1} {net243}
eco_connect {_16573_} {S} {net235}
eco_connect {_16581_} {S} {net235}
eco_connect {_16589_} {S} {net235}
eco_connect {_16597_} {S} {net235}
eco_connect {_16604_} {S} {net235}
eco_connect {_16611_} {S} {net235}
eco_connect {_16619_} {S} {net240}
eco_connect {_16649_} {S} {net243}
eco_connect {_16656_} {S} {net243}
eco_connect {_16670_} {S} {net243}
eco_connect {_16756_} {S} {net236}
eco_connect {_16758_} {S} {net236}
eco_connect {_16760_} {S} {net236}
eco_connect {_16840_} {S} {net239}
eco_connect {_16846_} {S} {net239}
eco_connect {_17029_} {S} {net242}
eco_connect {_17031_} {S} {net242}
eco_connect {_17140_} {A2} {net234}
eco_connect {_17205_} {A2} {net234}
eco_connect {_17231_} {A2} {net234}
eco_connect {_17247_} {C} {net234}
eco_connect {_17269_} {A1} {net234}
eco_connect {_17289_} {A1} {net234}
eco_connect {_17308_} {A1} {net234}
eco_connect {_17329_} {C} {net234}
eco_connect {_17350_} {C} {net234}
eco_connect {_17370_} {C} {net234}
eco_connect {_17391_} {A1} {net234}
eco_connect {_17411_} {C} {net234}
eco_connect {max_cap101} {I} {net225}
eco_connect {max_cap130} {I} {net228}
eco_connect {max_cap131} {I} {net228}
eco_connect {max_cap158} {I} {net230}
eco_connect {wire181} {I} {net232}

# ----- 16 commutative pin swaps from extracted-aware repair_timing -----
puts "ECO_PIN_SWAPS 16"
eco_connect {_09700_} {A1} {_04488_}
eco_connect {_09700_} {A2} {_04356_}
eco_connect {_09848_} {A1} {_04620_}
eco_connect {_09848_} {A2} {_04499_}
eco_connect {_11548_} {A1} {u_transform_scheduler_core.dft12_phase\[0\]}
eco_connect {_11548_} {A2} {_03920_}
eco_connect {_15855_} {A1} {_04356_}
eco_connect {_15855_} {A2} {_03895_}
eco_connect {_15946_} {A1} {_04357_}
eco_connect {_15946_} {A4} {u_transform_scheduler_core.rx_state\[14\]}
eco_connect {_15962_} {A1} {_02484_}
eco_connect {_15962_} {A2} {_02475_}
eco_connect {_15999_} {A1} {_02531_}
eco_connect {_15999_} {A2} {_02512_}
eco_connect {_16105_} {A1} {_02509_}
eco_connect {_16105_} {A4} {_02497_}
eco_connect {_16106_} {A1} {_02521_}
eco_connect {_16106_} {A2} {_02517_}
eco_connect {_16115_} {A1} {_02631_}
eco_connect {_16115_} {A2} {_02624_}
eco_connect {_16199_} {A1} {_02497_}
eco_connect {_16199_} {A2} {_02701_}
eco_connect {_16297_} {B1} {_02519_}
eco_connect {_16297_} {B2} {_02488_}
eco_connect {_16302_} {A1} {_02772_}
eco_connect {_16302_} {A2} {_02510_}
eco_connect {_16336_} {A1} {_02772_}
eco_connect {_16336_} {A2} {_02623_}
eco_connect {_16477_} {A1} {_02847_}
eco_connect {_16477_} {A2} {_02625_}
eco_connect {_16478_} {A1} {_02850_}
eco_connect {_16478_} {A2} {_02623_}

# ----- 175 master swaps (164 from extracted-aware repair + 15 later targeted) -----
puts "ECO_RESIZES 175"
set inst [eco_must_inst {_09098_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__inv_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09098_ -> gf180mcu_fd_sc_mcu9t5v0__inv_2" }
set inst [eco_must_inst {_09101_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__inv_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09101_ -> gf180mcu_fd_sc_mcu9t5v0__inv_2" }
set inst [eco_must_inst {_09262_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__inv_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09262_ -> gf180mcu_fd_sc_mcu9t5v0__inv_2" }
set inst [eco_must_inst {_09390_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09390_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_4" }
set inst [eco_must_inst {_09391_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__or2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09391_ -> gf180mcu_fd_sc_mcu9t5v0__or2_2" }
set inst [eco_must_inst {_09394_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nand2_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09394_ -> gf180mcu_fd_sc_mcu9t5v0__nand2_4" }
set inst [eco_must_inst {_09395_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__inv_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09395_ -> gf180mcu_fd_sc_mcu9t5v0__inv_4" }
set inst [eco_must_inst {_09399_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__and3_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09399_ -> gf180mcu_fd_sc_mcu9t5v0__and3_4" }
set inst [eco_must_inst {_09401_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09401_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_4" }
set inst [eco_must_inst {_09416_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi211_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09416_ -> gf180mcu_fd_sc_mcu9t5v0__aoi211_4" }
set inst [eco_must_inst {_09417_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__clkinv_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09417_ -> gf180mcu_fd_sc_mcu9t5v0__clkinv_4" }
set inst [eco_must_inst {_09422_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09422_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_2" }
set inst [eco_must_inst {_09423_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nand3_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09423_ -> gf180mcu_fd_sc_mcu9t5v0__nand3_2" }
set inst [eco_must_inst {_09424_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi21_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09424_ -> gf180mcu_fd_sc_mcu9t5v0__aoi21_2" }
set inst [eco_must_inst {_09425_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09425_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_4" }
set inst [eco_must_inst {_09432_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09432_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_2" }
set inst [eco_must_inst {_09435_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai31_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09435_ -> gf180mcu_fd_sc_mcu9t5v0__oai31_2" }
set inst [eco_must_inst {_09450_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai31_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09450_ -> gf180mcu_fd_sc_mcu9t5v0__oai31_4" }
set inst [eco_must_inst {_09454_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__and4_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09454_ -> gf180mcu_fd_sc_mcu9t5v0__and4_4" }
set inst [eco_must_inst {_09456_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nand2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09456_ -> gf180mcu_fd_sc_mcu9t5v0__nand2_2" }
set inst [eco_must_inst {_09461_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nand2_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09461_ -> gf180mcu_fd_sc_mcu9t5v0__nand2_4" }
set inst [eco_must_inst {_09462_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__clkinv_16}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09462_ -> gf180mcu_fd_sc_mcu9t5v0__clkinv_16" }
set inst [eco_must_inst {_09473_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai211_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09473_ -> gf180mcu_fd_sc_mcu9t5v0__oai211_2" }
set inst [eco_must_inst {_09478_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__and2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09478_ -> gf180mcu_fd_sc_mcu9t5v0__and2_2" }
set inst [eco_must_inst {_09486_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09486_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_2" }
set inst [eco_must_inst {_09490_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi21_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09490_ -> gf180mcu_fd_sc_mcu9t5v0__aoi21_2" }
set inst [eco_must_inst {_09492_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi21_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09492_ -> gf180mcu_fd_sc_mcu9t5v0__aoi21_2" }
set inst [eco_must_inst {_09506_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi21_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09506_ -> gf180mcu_fd_sc_mcu9t5v0__aoi21_2" }
set inst [eco_must_inst {_09512_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nand2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09512_ -> gf180mcu_fd_sc_mcu9t5v0__nand2_2" }
set inst [eco_must_inst {_09515_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor3_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09515_ -> gf180mcu_fd_sc_mcu9t5v0__nor3_2" }
set inst [eco_must_inst {_09518_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi21_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09518_ -> gf180mcu_fd_sc_mcu9t5v0__aoi21_2" }
set inst [eco_must_inst {_09519_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai31_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09519_ -> gf180mcu_fd_sc_mcu9t5v0__oai31_4" }
set inst [eco_must_inst {_09541_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi21_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09541_ -> gf180mcu_fd_sc_mcu9t5v0__aoi21_4" }
set inst [eco_must_inst {_09542_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai211_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09542_ -> gf180mcu_fd_sc_mcu9t5v0__oai211_4" }
set inst [eco_must_inst {_09668_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor4_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09668_ -> gf180mcu_fd_sc_mcu9t5v0__nor4_2" }
set inst [eco_must_inst {_09702_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nand3_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09702_ -> gf180mcu_fd_sc_mcu9t5v0__nand3_2" }
set inst [eco_must_inst {_09854_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09854_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_4" }
set inst [eco_must_inst {_09877_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09877_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_2" }
set inst [eco_must_inst {_09881_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor3_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09881_ -> gf180mcu_fd_sc_mcu9t5v0__nor3_2" }
set inst [eco_must_inst {_09882_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09882_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_4" }
set inst [eco_must_inst {_09895_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09895_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_2" }
set inst [eco_must_inst {_09901_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09901_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_2" }
set inst [eco_must_inst {_09905_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09905_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_2" }
set inst [eco_must_inst {_09907_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09907_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_2" }
set inst [eco_must_inst {_09910_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09910_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_2" }
set inst [eco_must_inst {_09911_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09911_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_2" }
set inst [eco_must_inst {_09912_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _09912_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_2" }
set inst [eco_must_inst {_10193_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10193_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_2" }
set inst [eco_must_inst {_10216_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10216_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_2" }
set inst [eco_must_inst {_10224_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nand2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10224_ -> gf180mcu_fd_sc_mcu9t5v0__nand2_2" }
set inst [eco_must_inst {_10240_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nand2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10240_ -> gf180mcu_fd_sc_mcu9t5v0__nand2_2" }
set inst [eco_must_inst {_10243_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10243_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_2" }
set inst [eco_must_inst {_10252_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10252_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_2" }
set inst [eco_must_inst {_10256_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10256_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_2" }
set inst [eco_must_inst {_10286_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi22_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10286_ -> gf180mcu_fd_sc_mcu9t5v0__aoi22_2" }
set inst [eco_must_inst {_10314_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi22_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10314_ -> gf180mcu_fd_sc_mcu9t5v0__aoi22_2" }
set inst [eco_must_inst {_10340_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi22_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10340_ -> gf180mcu_fd_sc_mcu9t5v0__aoi22_2" }
set inst [eco_must_inst {_10368_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi22_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10368_ -> gf180mcu_fd_sc_mcu9t5v0__aoi22_2" }
set inst [eco_must_inst {_10388_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10388_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_2" }
set inst [eco_must_inst {_10437_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi222_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10437_ -> gf180mcu_fd_sc_mcu9t5v0__aoi222_2" }
set inst [eco_must_inst {_10445_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor3_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10445_ -> gf180mcu_fd_sc_mcu9t5v0__nor3_4" }
set inst [eco_must_inst {_10495_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi221_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10495_ -> gf180mcu_fd_sc_mcu9t5v0__aoi221_2" }
set inst [eco_must_inst {_10565_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi222_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10565_ -> gf180mcu_fd_sc_mcu9t5v0__aoi222_2" }
set inst [eco_must_inst {_10661_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10661_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_4" }
set inst [eco_must_inst {_10667_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai31_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10667_ -> gf180mcu_fd_sc_mcu9t5v0__oai31_2" }
set inst [eco_must_inst {_10668_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi221_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10668_ -> gf180mcu_fd_sc_mcu9t5v0__aoi221_4" }
set inst [eco_must_inst {_10676_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi21_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10676_ -> gf180mcu_fd_sc_mcu9t5v0__aoi21_4" }
set inst [eco_must_inst {_10683_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi22_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10683_ -> gf180mcu_fd_sc_mcu9t5v0__aoi22_2" }
set inst [eco_must_inst {_10696_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi22_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10696_ -> gf180mcu_fd_sc_mcu9t5v0__aoi22_4" }
set inst [eco_must_inst {_10704_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi221_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10704_ -> gf180mcu_fd_sc_mcu9t5v0__aoi221_4" }
set inst [eco_must_inst {_10719_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10719_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_4" }
set inst [eco_must_inst {_10729_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi22_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10729_ -> gf180mcu_fd_sc_mcu9t5v0__aoi22_2" }
set inst [eco_must_inst {_10743_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi22_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10743_ -> gf180mcu_fd_sc_mcu9t5v0__aoi22_4" }
set inst [eco_must_inst {_10749_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai21_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10749_ -> gf180mcu_fd_sc_mcu9t5v0__oai21_2" }
set inst [eco_must_inst {_10750_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi221_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10750_ -> gf180mcu_fd_sc_mcu9t5v0__aoi221_4" }
set inst [eco_must_inst {_10770_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi21_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10770_ -> gf180mcu_fd_sc_mcu9t5v0__aoi21_4" }
set inst [eco_must_inst {_10775_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi221_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10775_ -> gf180mcu_fd_sc_mcu9t5v0__aoi221_4" }
set inst [eco_must_inst {_10792_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi21_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10792_ -> gf180mcu_fd_sc_mcu9t5v0__aoi21_2" }
set inst [eco_must_inst {_10796_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi22_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10796_ -> gf180mcu_fd_sc_mcu9t5v0__aoi22_2" }
set inst [eco_must_inst {_10810_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi22_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _10810_ -> gf180mcu_fd_sc_mcu9t5v0__aoi22_2" }
set inst [eco_must_inst {_11075_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nand2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _11075_ -> gf180mcu_fd_sc_mcu9t5v0__nand2_2" }
set inst [eco_must_inst {_11079_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi21_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _11079_ -> gf180mcu_fd_sc_mcu9t5v0__aoi21_4" }
set inst [eco_must_inst {_11082_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _11082_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_2" }
set inst [eco_must_inst {_11083_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nand2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _11083_ -> gf180mcu_fd_sc_mcu9t5v0__nand2_2" }
set inst [eco_must_inst {_11325_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nand2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _11325_ -> gf180mcu_fd_sc_mcu9t5v0__nand2_2" }
set inst [eco_must_inst {_11553_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__mux2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _11553_ -> gf180mcu_fd_sc_mcu9t5v0__mux2_2" }
set inst [eco_must_inst {_11554_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__mux2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _11554_ -> gf180mcu_fd_sc_mcu9t5v0__mux2_2" }
set inst [eco_must_inst {_11557_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi211_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _11557_ -> gf180mcu_fd_sc_mcu9t5v0__aoi211_4" }
set inst [eco_must_inst {_11558_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai211_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _11558_ -> gf180mcu_fd_sc_mcu9t5v0__oai211_4" }
set inst [eco_must_inst {_11559_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi21_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _11559_ -> gf180mcu_fd_sc_mcu9t5v0__aoi21_2" }
set inst [eco_must_inst {_11574_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai31_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _11574_ -> gf180mcu_fd_sc_mcu9t5v0__oai31_2" }
set inst [eco_must_inst {_11588_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi22_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _11588_ -> gf180mcu_fd_sc_mcu9t5v0__aoi22_2" }
set inst [eco_must_inst {_11898_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai31_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _11898_ -> gf180mcu_fd_sc_mcu9t5v0__oai31_2" }
set inst [eco_must_inst {_12553_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai32_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _12553_ -> gf180mcu_fd_sc_mcu9t5v0__oai32_2" }
set inst [eco_must_inst {_12561_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai32_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _12561_ -> gf180mcu_fd_sc_mcu9t5v0__oai32_2" }
set inst [eco_must_inst {_12727_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _12727_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_2" }
set inst [eco_must_inst {_13042_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nand3_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _13042_ -> gf180mcu_fd_sc_mcu9t5v0__nand3_2" }
set inst [eco_must_inst {_15481_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__or4_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15481_ -> gf180mcu_fd_sc_mcu9t5v0__or4_2" }
set inst [eco_must_inst {_15681_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor3_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15681_ -> gf180mcu_fd_sc_mcu9t5v0__nor3_2" }
set inst [eco_must_inst {_15859_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15859_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_4" }
set inst [eco_must_inst {_15860_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__or2_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15860_ -> gf180mcu_fd_sc_mcu9t5v0__or2_4" }
set inst [eco_must_inst {_15861_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nand2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15861_ -> gf180mcu_fd_sc_mcu9t5v0__nand2_2" }
set inst [eco_must_inst {_15862_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15862_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_2" }
set inst [eco_must_inst {_15865_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15865_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_2" }
set inst [eco_must_inst {_15937_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi21_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15937_ -> gf180mcu_fd_sc_mcu9t5v0__aoi21_4" }
set inst [eco_must_inst {_15940_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai21_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15940_ -> gf180mcu_fd_sc_mcu9t5v0__oai21_2" }
set inst [eco_must_inst {_15942_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15942_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_4" }
set inst [eco_must_inst {_15943_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__or2_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15943_ -> gf180mcu_fd_sc_mcu9t5v0__or2_4" }
set inst [eco_must_inst {_15944_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor3_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15944_ -> gf180mcu_fd_sc_mcu9t5v0__nor3_4" }
set inst [eco_must_inst {_15949_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nand4_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15949_ -> gf180mcu_fd_sc_mcu9t5v0__nand4_4" }
set inst [eco_must_inst {_15960_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi21_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15960_ -> gf180mcu_fd_sc_mcu9t5v0__aoi21_2" }
set inst [eco_must_inst {_15967_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai211_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15967_ -> gf180mcu_fd_sc_mcu9t5v0__oai211_2" }
set inst [eco_must_inst {_15968_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__and2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15968_ -> gf180mcu_fd_sc_mcu9t5v0__and2_2" }
set inst [eco_must_inst {_15969_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi22_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15969_ -> gf180mcu_fd_sc_mcu9t5v0__aoi22_4" }
set inst [eco_must_inst {_15970_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nand4_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15970_ -> gf180mcu_fd_sc_mcu9t5v0__nand4_4" }
set inst [eco_must_inst {_15973_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai211_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15973_ -> gf180mcu_fd_sc_mcu9t5v0__oai211_2" }
set inst [eco_must_inst {_15977_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nand4_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15977_ -> gf180mcu_fd_sc_mcu9t5v0__nand4_4" }
set inst [eco_must_inst {_15981_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor3_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15981_ -> gf180mcu_fd_sc_mcu9t5v0__nor3_2" }
set inst [eco_must_inst {_15984_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor3_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15984_ -> gf180mcu_fd_sc_mcu9t5v0__nor3_2" }
set inst [eco_must_inst {_15985_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi221_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15985_ -> gf180mcu_fd_sc_mcu9t5v0__aoi221_4" }
set inst [eco_must_inst {_15986_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai221_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15986_ -> gf180mcu_fd_sc_mcu9t5v0__oai221_4" }
set inst [eco_must_inst {_15987_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor3_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15987_ -> gf180mcu_fd_sc_mcu9t5v0__nor3_4" }
set inst [eco_must_inst {_15988_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai211_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15988_ -> gf180mcu_fd_sc_mcu9t5v0__oai211_4" }
set inst [eco_must_inst {_15991_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai32_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15991_ -> gf180mcu_fd_sc_mcu9t5v0__oai32_4" }
set inst [eco_must_inst {_15993_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nand4_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15993_ -> gf180mcu_fd_sc_mcu9t5v0__nand4_4" }
set inst [eco_must_inst {_15996_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi21_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _15996_ -> gf180mcu_fd_sc_mcu9t5v0__aoi21_2" }
set inst [eco_must_inst {_16050_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nand4_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16050_ -> gf180mcu_fd_sc_mcu9t5v0__nand4_2" }
set inst [eco_must_inst {_16051_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai21_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16051_ -> gf180mcu_fd_sc_mcu9t5v0__oai21_2" }
set inst [eco_must_inst {_16063_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai21_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16063_ -> gf180mcu_fd_sc_mcu9t5v0__oai21_2" }
set inst [eco_must_inst {_16069_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai21_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16069_ -> gf180mcu_fd_sc_mcu9t5v0__oai21_2" }
set inst [eco_must_inst {_16074_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai21_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16074_ -> gf180mcu_fd_sc_mcu9t5v0__oai21_2" }
set inst [eco_must_inst {_16081_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai21_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16081_ -> gf180mcu_fd_sc_mcu9t5v0__oai21_2" }
set inst [eco_must_inst {_16086_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai21_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16086_ -> gf180mcu_fd_sc_mcu9t5v0__oai21_2" }
set inst [eco_must_inst {_16093_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai21_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16093_ -> gf180mcu_fd_sc_mcu9t5v0__oai21_2" }
set inst [eco_must_inst {_16098_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai21_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16098_ -> gf180mcu_fd_sc_mcu9t5v0__oai21_2" }
set inst [eco_must_inst {_16107_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai211_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16107_ -> gf180mcu_fd_sc_mcu9t5v0__oai211_4" }
set inst [eco_must_inst {_16108_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16108_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_4" }
set inst [eco_must_inst {_16109_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nand2_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16109_ -> gf180mcu_fd_sc_mcu9t5v0__nand2_4" }
set inst [eco_must_inst {_16112_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi21_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16112_ -> gf180mcu_fd_sc_mcu9t5v0__aoi21_4" }
set inst [eco_must_inst {_16114_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__and2_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16114_ -> gf180mcu_fd_sc_mcu9t5v0__and2_4" }
set inst [eco_must_inst {_16196_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16196_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_2" }
set inst [eco_must_inst {_16197_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai211_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16197_ -> gf180mcu_fd_sc_mcu9t5v0__oai211_4" }
set inst [eco_must_inst {_16233_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16233_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_2" }
set inst [eco_must_inst {_16234_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nand2_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16234_ -> gf180mcu_fd_sc_mcu9t5v0__nand2_2" }
set inst [eco_must_inst {_16297_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai32_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16297_ -> gf180mcu_fd_sc_mcu9t5v0__oai32_2" }
set inst [eco_must_inst {_16299_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nand2_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16299_ -> gf180mcu_fd_sc_mcu9t5v0__nand2_4" }
set inst [eco_must_inst {_16335_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nand2_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16335_ -> gf180mcu_fd_sc_mcu9t5v0__nand2_4" }
set inst [eco_must_inst {_16369_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__and4_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16369_ -> gf180mcu_fd_sc_mcu9t5v0__and4_4" }
set inst [eco_must_inst {_16370_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi21_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16370_ -> gf180mcu_fd_sc_mcu9t5v0__aoi21_4" }
set inst [eco_must_inst {_16404_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nor2_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16404_ -> gf180mcu_fd_sc_mcu9t5v0__nor2_4" }
set inst [eco_must_inst {_16440_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi21_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16440_ -> gf180mcu_fd_sc_mcu9t5v0__aoi21_2" }
set inst [eco_must_inst {_16441_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nand2_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16441_ -> gf180mcu_fd_sc_mcu9t5v0__nand2_4" }
set inst [eco_must_inst {_16444_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai21_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16444_ -> gf180mcu_fd_sc_mcu9t5v0__oai21_4" }
set inst [eco_must_inst {_16511_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__and4_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16511_ -> gf180mcu_fd_sc_mcu9t5v0__and4_4" }
set inst [eco_must_inst {_16512_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi21_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16512_ -> gf180mcu_fd_sc_mcu9t5v0__aoi21_4" }
set inst [eco_must_inst {_16620_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__nand4_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16620_ -> gf180mcu_fd_sc_mcu9t5v0__nand4_2" }
set inst [eco_must_inst {_16621_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai21_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16621_ -> gf180mcu_fd_sc_mcu9t5v0__oai21_2" }
set inst [eco_must_inst {_16627_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai21_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16627_ -> gf180mcu_fd_sc_mcu9t5v0__oai21_2" }
set inst [eco_must_inst {_16633_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai21_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16633_ -> gf180mcu_fd_sc_mcu9t5v0__oai21_2" }
set inst [eco_must_inst {_16639_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai21_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16639_ -> gf180mcu_fd_sc_mcu9t5v0__oai21_2" }
set inst [eco_must_inst {_16645_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai21_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16645_ -> gf180mcu_fd_sc_mcu9t5v0__oai21_2" }
set inst [eco_must_inst {_16652_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai21_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16652_ -> gf180mcu_fd_sc_mcu9t5v0__oai21_2" }
set inst [eco_must_inst {_16666_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai21_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16666_ -> gf180mcu_fd_sc_mcu9t5v0__oai21_2" }
set inst [eco_must_inst {_16672_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__oai21_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16672_ -> gf180mcu_fd_sc_mcu9t5v0__oai21_2" }
set inst [eco_must_inst {_16710_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__aoi211_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _16710_ -> gf180mcu_fd_sc_mcu9t5v0__aoi211_2" }
set inst [eco_must_inst {_18566_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__dffrnq_4}]
if {![$inst swapMaster $master]} { error "swapMaster failed _18566_ -> gf180mcu_fd_sc_mcu9t5v0__dffrnq_4" }
set inst [eco_must_inst {_18567_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__dffrnq_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _18567_ -> gf180mcu_fd_sc_mcu9t5v0__dffrnq_2" }
set inst [eco_must_inst {_18568_}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__dffrnq_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed _18568_ -> gf180mcu_fd_sc_mcu9t5v0__dffrnq_2" }
set inst [eco_must_inst {input1}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__clkbuf_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed input1 -> gf180mcu_fd_sc_mcu9t5v0__clkbuf_2" }
set inst [eco_must_inst {input2}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__clkbuf_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed input2 -> gf180mcu_fd_sc_mcu9t5v0__clkbuf_2" }
set inst [eco_must_inst {input4}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__clkbuf_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed input4 -> gf180mcu_fd_sc_mcu9t5v0__clkbuf_2" }
set inst [eco_must_inst {input5}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__clkbuf_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed input5 -> gf180mcu_fd_sc_mcu9t5v0__clkbuf_2" }
set inst [eco_must_inst {input6}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__clkbuf_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed input6 -> gf180mcu_fd_sc_mcu9t5v0__clkbuf_2" }
set inst [eco_must_inst {input7}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__clkbuf_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed input7 -> gf180mcu_fd_sc_mcu9t5v0__clkbuf_2" }
set inst [eco_must_inst {input8}]
set master [eco_must_master {gf180mcu_fd_sc_mcu9t5v0__clkbuf_2}]
if {![$inst swapMaster $master]} { error "swapMaster failed input8 -> gf180mcu_fd_sc_mcu9t5v0__clkbuf_2" }

puts "ECO_AFTER_LOGICAL insts [llength [$block getInsts]]"
write_db [file join $outdir butterfold_top_eco_prelegal.odb]
write_def [file join $outdir butterfold_top_eco_prelegal.def]

puts "ECO_LEGALIZE_BEGIN"
set rc [catch {detailed_placement -incremental -max_displacement {50 80}} msg]
puts "ECO_LEGALIZE_RC $rc $msg"
if {$rc} { exit 1 }
if {[catch {check_placement -verbose} cmsg]} {
  puts "ECO_CHECK_PLACEMENT $cmsg"
} else {
  puts "ECO_CHECK_PLACEMENT_OK"
}
write_db [file join $outdir butterfold_top_eco_legal.odb]
write_def [file join $outdir butterfold_top_eco_legal.def]

# Restore diode placement status to PLACED (matches the closed checkpoint).
foreach inst [$block getInsts] {
  set m [[$inst getMaster] getName]
  if {[string match "*__antenna" $m]} {
    $inst setDoNotTouch 0
    $inst setPlacementStatus PLACED
  }
}

if {$do_route} {
  puts "ECO_ROUTE_BEGIN"
  # Preserve PDN special wires, CTS topology/NDR, diodes; drop ordinary dbWires.
  foreach net [$block getNets] {
    set st [$net getSigType]
    if {[string match *POWER* $st] || [string match *GROUND* $st]} { continue }
    if {[$net getWire] ne "" && [$net getWire] ne "NULL"} {
      odb::dbWire_destroy [$net getWire]
    }
    $net clearGuides
  }
  write_db [file join $outdir butterfold_top_eco_clean_unrouted.odb]
  set_routing_layers -signal Metal2-Metal5 -clock Metal2-Metal5
  foreach layer {Metal2 Metal3 Metal4 Metal5} {
    set_global_routing_layer_adjustment $layer 0.3
  }
  global_connect
  global_route -congestion_iterations 50 -verbose -guide_file [file join $outdir butterfold_top_eco.guide]
  write_db [file join $outdir butterfold_top_eco_grt.odb]
  detailed_route -droute_end_iter 64 -or_seed 42 -verbose 1 -output_drc [file join $outdir butterfold_top_eco.drc]
  write_db [file join $outdir butterfold_top_eco_routed.odb]
  write_def [file join $outdir butterfold_top_eco_routed.def]
  puts "ECO_ROUTE_DONE"
} else {
  puts "ECO_ROUTE_SKIPPED set ECO_ROUTE=1 to GRT+DRT after legalization"
}

puts "ECO_COMPLETE"
puts "NEXT: extract max SPEF with rules.openrcx.gf180mcuD.max and run max_ss_125C_4v50 STA"
puts "      expected closed result: setup WNS +0.177954 ns  TNS 0  violations 0"

