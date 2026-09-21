set dir [file dirname [info script]]

create_project $::env(PROJECT_NAME) [file normalize [file join $dir .. $::env(PROJECT_NAME)]]

