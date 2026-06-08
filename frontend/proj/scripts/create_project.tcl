set board_name "digilentinc.com:zybo:part0:2.0"
set part [get_property PART_NAME [get_board_parts -quiet $board_name]]

create_project $::env(PROJECT_NAME) $::env(PROJ_DIR)/tools/vivado -part $part
set_property BOARD_PART $board_name [current_project]
