proc add_files_from_f_paths {
    f_path_dirs
    {fileset sources_1}
} {
    foreach f_path $f_path_dirs {
        set base_f_path [file dirname $f_path]; # To remove .f from the path

        set fp [open $f_path r]

        while {[gets $fp line] >= 0} {
            regsub {//.*} $line "" line; # removing comments

            if {$line eq ""} {
                continue
            }

            add_files -fileset $fileset [file join $base_f_path $line]
        }

        close $fp
    }
}

