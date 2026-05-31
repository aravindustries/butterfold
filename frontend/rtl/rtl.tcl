namespace eval rtl {
    variable dir [file dirname [info script]];
}

# reset_property top_file [get_filesets sources_1]
# reset_property top [get_filesets sources_1]

#################### Begin ##############################

source -notrace [file join $rtl::dir "ip/ip.tcl"]
source -notrace [file join $rtl::dir "src/src.tcl"]

# set_property top zynq_top [get_filesets sources_1]
# update_compile_order -fileset sources_1

################### End #################################

