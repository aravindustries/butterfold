namespace eval ip {
    variable dir [file dirname [info script]];
}

# Init
set ip_dirs {}

#################### Begin ##############################

# lappend ip_dirs clk_wiz_0
# lappend ip_dirs ila_0
# lappend ip_dirs ila_1

#################### End ################################

foreach ip_dir $ip_dirs {
    set abs_ip_path [file join $ip::dir $ip_dir]
    add_files -fileset sources_1 [glob -nocomplain -directory $abs_ip_path -types {f} *.xci]
}

