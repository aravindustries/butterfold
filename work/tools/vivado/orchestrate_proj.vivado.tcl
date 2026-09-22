# Remove existing files
remove_files [get_files -quiet -of_objects [get_filesets sources_1]]
remove_files [get_files -quiet -of_objects [get_filesets constrs_1]]

# # Disable auto-compile order (don't know if it works)
# set_property source_mgmt_mode None [current_project]

######## Begin #########

source -notrace $::env(RTL_DIR)/rtl.vivado.tcl
source -notrace $::env(SIM_DIR)/sim.vivado.tcl
# source -notrace $::env(SYN_DIR)/syn.vivado.tcl

######## End  ##########

check_syntax; # warn of nets used without declarations

