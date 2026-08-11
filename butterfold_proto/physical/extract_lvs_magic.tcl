drc off
locking off
gds readonly false
gds rescale true
if {![info exists ::env(LVS_LAYOUT_GDS)]} { error "LVS_LAYOUT_GDS is required" }
if {![info exists ::env(LVS_LAYOUT_SPICE)]} { error "LVS_LAYOUT_SPICE is required" }
gds read $::env(LVS_LAYOUT_GDS)
load butterfold_padframe_top
select top cell
extract do local
extract no capacitance
extract no coupling
extract no resistance
extract all
ext2spice hierarchy on
ext2spice scale off
ext2spice format ngspice
ext2spice cthresh infinite
ext2spice rthresh infinite
ext2spice -o $::env(LVS_LAYOUT_SPICE) butterfold_padframe_top
quit -noprompt
