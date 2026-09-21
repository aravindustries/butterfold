namespace eval syn {
    variable dir [file dirname [info script]];

    #################### Begin ##############################

    set constrs {}

    set board_name "digilentinc.com:zybo:part0:2.0"

    # lappend constrs "design/timing_async_fifo.xdc"
    # lappend constrs "design/debug.xdc"
    # lappend constrs "boards/Zybo-pinout.xdc"

    ##################### End ###############################

    if {[get_board_parts -quiet $board_name] eq ""} {
        error "ERROR: Board part '$board_name' not found in Vivado board store. Please install Digilent board files."
    }
    set_property BOARD_PART $board_name [current_project]
    foreach constr $constrs {
        add_files -fileset constrs_1 [file normalize [file join $dir $constr]]
    }
}

