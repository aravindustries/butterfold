set board_name "digilentinc.com:zybo:part0:2.0"
set board_obj [get_board_parts -quiet $board_name]

if {$board_obj eq ""} {
    error "ERROR: Board part '$board_name' not found in Vivado board store. Please install Digilent board files."
}

create_project -force $::env(PROJECT_NAME) $::env(PROJ_DIR)/tools/vivado -part [get_property PART_NAME $board_obj]
set_property BOARD_PART $board_name [current_project]

