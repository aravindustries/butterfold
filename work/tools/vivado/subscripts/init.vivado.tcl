set dir [file dirname [info script]]

open_project [file join $dir .. $::env(PROJECT_NAME) $::env(PROJECT_NAME).xpr]
source -notrace [file join $dir .. orchestrate_proj.vivado.tcl]

