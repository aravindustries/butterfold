namespace eval constrs {
    variable dir [file dirname [info script]];
}

# Init
set constr_paths {}

#################### Begin ##############################

lappend constr_paths "boards/Zybo-pinout.xdc"
lappend constr_paths "design/debug.xdc"
lappend constr_paths "design/timing.xdc"

##################### End ###############################

foreach constr_path $constr_paths {
    set abs_constr_path [file join $constrs::dir $constr_path]
    add_files -fileset constrs_1 $abs_constr_path
}

