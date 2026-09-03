# Re-run the proven LibreLane Magic device-extraction method on the exact
# final ACH candidate GDS.  The generated baseline environment records the
# complete PDK model inventory; only revision-specific paths are overridden.
set proto /headless/aravindustries-repos/butterfold/butterfold_proto
source $proto/physical/results/m2_fix/lvs/extract/_env.tcl
if {[info exists ::env(FINAL_ACH_GDS)]} {
    set ::env(CURRENT_GDS) $::env(FINAL_ACH_GDS)
} else {
    set ::env(CURRENT_GDS) $proto/physical/results/m2_fix/candidate/butterfold_top.gds
}
if {[info exists ::env(FINAL_ACH_DEF)]} {
    set ::env(CURRENT_DEF) $::env(FINAL_ACH_DEF)
} else {
    set ::env(CURRENT_DEF) $proto/physical/results/m2_fix/filled.def
}
set ::env(STEP_DIR) $proto/physical/results/m2_fix/final_ach_lvs/extract
set ::env(SAVE_SPICE) $::env(STEP_DIR)/butterfold_top.spice
set ::env(MAGIC_EXT_USE_GDS) 1
set ::env(MAGIC_EXT_UNIQUE) all
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
extract unique all
extract
ext2spice lvs
ext2spice -o $::env(STEP_DIR)/butterfold_top.spice butterfold_top.ext
quit -noprompt
