namespace eval src {
    variable dir [file dirname [info script]];
}

# Init
set src_files {}

#################### Begin ##############################

# lappend src_files "counter.sv"

# # Default Top File
# lappend src_files "board_top/zynq_top.sv"

################### End #################################

foreach src_file $src_files {
    add_files -fileset sources_1 [file join $src::dir $src_file]
}

