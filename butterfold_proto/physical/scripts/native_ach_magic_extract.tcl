# Magic device extraction on the native-ring + ACH-shell GDS.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
source $proto/physical/results/m2_fix/lvs/extract/_env.tcl
set ::env(CURRENT_GDS) $proto/physical/results/native_power_ring_ach/candidate/butterfold_top.gds
if {[info exists ::env(FINAL_ACH_GDS)] && $::env(FINAL_ACH_GDS) ne ""} {
    set ::env(CURRENT_GDS) $::env(FINAL_ACH_GDS)
}
set ::env(CURRENT_DEF) $proto/physical/results/native_power_ring_ach/filled.def
if {[info exists ::env(FINAL_ACH_DEF)] && $::env(FINAL_ACH_DEF) ne ""} {
    set ::env(CURRENT_DEF) $::env(FINAL_ACH_DEF)
}
# _env.tcl overwrites STEP_DIR; restore the caller value if provided.
if {[info exists ::env(MAGIC_STEP_DIR)] && $::env(MAGIC_STEP_DIR) ne ""} {
    set ::env(STEP_DIR) $::env(MAGIC_STEP_DIR)
} elseif {![info exists ::env(STEP_DIR)] || $::env(STEP_DIR) eq ""} {
    set ::env(STEP_DIR) $proto/physical/results/native_power_ring_ach/lvs/extract
}
set ::env(SAVE_SPICE) $::env(STEP_DIR)/butterfold_top.spice
set ::env(MAGIC_EXT_USE_GDS) 1
if {![info exists ::env(MAGIC_NO_UNIQUE)] || $::env(MAGIC_NO_UNIQUE) eq ""} {
    set ::env(MAGIC_EXT_UNIQUE) all
}
file mkdir $::env(STEP_DIR)
source $::env(SCRIPTS_DIR)/magic/common/read.tcl
gds rescale true
gds readonly false
gds read $::env(CURRENT_GDS)
read_macro_lef
read_pdk_spice
load $::env(DESIGN_NAME) -dereference
load gf180mcu_fd_ip_sram__sram256x8m8wm1
property LEFview true
load $::env(DESIGN_NAME) -dereference
set extdir $::env(STEP_DIR)/extraction
file mkdir $extdir
cd $extdir
extract do local
extract no capacitance
extract no coupling
extract no resistance
extract no adjust
if {![info exists ::env(MAGIC_NO_UNIQUE)] || $::env(MAGIC_NO_UNIQUE) eq ""} {
    extract unique all
}
extract
ext2spice lvs
ext2spice -o $::env(STEP_DIR)/butterfold_top.spice butterfold_top.ext
quit -noprompt
