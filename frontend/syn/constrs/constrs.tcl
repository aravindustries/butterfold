namespace eval constrs {
    variable dir [file dirname [info script]];
}

# Init
set constr_files {}

#################### Begin ##############################

lappend constr_files "design/timing_async_fifo.xdc"
# lappend constr_paths "design/debug.xdc"
# lappend constr_files "boards/Zybo-pinout.xdc"

##################### End ###############################

foreach constr_file $constr_files {
    set abs_constr_path [file join $constrs::dir $constr_file]
    add_files -fileset constrs_1 $abs_constr_path
}

