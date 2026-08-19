namespace eval ip {
    variable dir [file dirname [info script]];
    set ip_dirs {}

    #################### Begin ##############################

    # lappend ip_dirs clk_wiz_0
    # lappend ip_dirs ila_0
    # lappend ip_dirs ila_1

    #################### End ################################

    foreach ip_dir $ip_dirs {
        set abs_ip_path [file join $ip::dir $ip_dir]
        set xci_files   [glob -nocomplain -directory $abs_ip_path -types {f} *.xci]
        if {[llength $xci_files] > 0} {
            add_files -norecurse -fileset sources_1 $xci_files
        }
    }
}

