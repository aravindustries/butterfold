# Remove existing files
remove_files [get_files -of_objects [get_filesets sources_1]]
remove_files [get_files -of_objects [get_filesets constrs_1]]

# # Optional - Disable auto-compile order (don't know if it works)
# set_property source_mgmt_mode None [current_project]

source -notrace $env(PROJ_DIR)/scripts/utils/utilities.tcl

######## Begin #########
source -notrace $env(RTL_DIR)/rtl.tcl
source -notrace $env(SYN_DIR)/constrs/constrs.tcl

######## End  ##########
check_syntax; # mainly to warn of nets used without declarations

