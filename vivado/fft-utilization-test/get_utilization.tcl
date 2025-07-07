package require json

cd [get_property directory [current_project]]
if {![file exists "reports/"]} {mkdir reports}

proc read_config { confname } {
    set f [open $confname]
    set data [read $f]
    close $f
    set data [json::json2dict $data]
    return $data
}

proc get_resources {fname {verbose 0}} {
    # read report file
    set err [ catch {set f [open "reports/${fname}.txt" r]} ]
    if {$err} {
        puts "ERROR: cannot read reports/${fname}.txt"
        return {}
    }
    set rep [read $f]
    close $f

    set vars {luts ffs slices brams dsps}
    foreach _ $vars {set $_ -}

    if {[regexp {\|\s*Slice LUTs\s*\|\s*([0-9\.]+)\s*\|} $rep _ luts]} {
        set luts [lindex $luts 0]
        if {$verbose} {puts "LUTs = $luts"}
    }

    if {[regexp {\|\s*Slice Registers\s*\|\s*([0-9\.]+)\s*\|} $rep _ ffs]} {
        set ffs [lindex $ffs 0]
        if {$verbose} {puts "FFs = $ffs"}
    }

    if {[regexp {\|\s*Slice\s*\|\s*([0-9\.]+)\s*\|} $rep _ slices]} {
        set slices [lindex $slices 0]
        if {$verbose} {puts "SLICEs = $slices"}
    }

    if {[regexp {\|\s*Block RAM Tile\s*\|\s*([0-9\.]+)\s*\|} $rep _ brams]} {
        set brams [lindex $brams 0]
        if {$verbose} {puts "BRAMs = $brams"}
    }

    if {[regexp {\|\s*DSPs\s*\|\s*([0-9\.]+)\s*\|} $rep _ dsps]} {
        set dsps [lindex $dsps 0]
        if {$verbose} {puts "DSPs = $dsps"}
    }

    set util [dict create luts $luts ffs $ffs slices $slices brams $brams dsps $dsps]
    return $util
}

proc getutil { params } {
    # make generic_string from params dict
    set generic_string {}
    foreach key [dict keys $params] {
        set val [dict get $params $key]
        lappend generic_string "${key}=${val}"
    }
    set generic_string [join $generic_string " "]

    # run synth + implementation
    set_property generic "$generic_string" [current_fileset]
    # set_property generic "DataWidth=16 TwiddleWidth=18 MaxShiftRegDelay=256 FFTlen=4096 BitReversedInput=0 Nchannels=1 UseFFT2=0" [current_fileset]
    reset_run synth_1
    launch_runs impl_1 -jobs 4
    wait_on_run impl_1
    open_run impl_1

    # write report
    set name [join ${generic_string} "_"]
    report_utilization -file reports/${name}.txt

    # read utilization from report file
    puts "reading report..."
    set u [get_resources $name 1]
    dict append u name $name
    return $u
}

proc util_format {util_dict} {
    set vars {luts ffs slices brams dsps name}
    foreach _ $vars {set $_ [dict get $util_dict $_]}
    return "| $name\t| $luts\t| $ffs\t| $brams\t| $dsps\t|"
}

proc log_reset {str logfile} {
    set f [open $logfile "w"]
    puts $f $str
    close $f
}

proc logwr {str logfile} {
    set f [open $logfile "a"]
    puts $f $str
    close $f
}

proc util_batch {{summary_file "reports/summary.txt"}} {
    set tbl_head "| name\t| luts\t| ffs\t| brams\t| dsps\t|"
    set start_time [clock format [clock seconds]]

    # List of parameters for runs
    set FFTlen_list {8 16 32 64 128 256 512 1024 2048 4096 8192 16384 32768 65536}
    lappend FFTlen_list {*}$FFTlen_list
    lappend FFTlen_list {*}$FFTlen_list
    set BitReversedInput_list   [lrepeat 14 0]
    lappend BitReversedInput_list {*}[lrepeat 14 1]
    lappend BitReversedInput_list {*}$BitReversedInput_list
    set UseFFT2_list [lrepeat 28 0]
    lappend UseFFT2_list {*}[lrepeat 28 1]

    set tmp "Start time: $start_time\n"
    set tmp "${tmp}FFTlen([llength $FFTlen_list]): $FFTlen_list\n"
    set tmp "${tmp}BitRev([llength $BitReversedInput_list]): ${BitReversedInput_list}\n"
    set tmp "${tmp}FFT2([llength $UseFFT2_list]): ${UseFFT2_list}\n"
    set tmp "$tmp\n${tbl_head}"
    log_reset $tmp $summary_file

    for {set k 0} {$k < [llength $FFTlen_list]} {incr k} {
        set params [dict create]
        dict append params FFTlen [lindex $FFTlen_list $k]
        dict append params BitReversedInput [lindex $BitReversedInput_list $k]
        dict append params UseFFT2 [lindex $UseFFT2_list $k]

        puts "STARTING: $params"
        set util_formatted [util_format [getutil $params]]
        puts $util_formatted
        set t [clock format [clock seconds]];   #run end time
        logwr "${util_formatted}\t\t$t" $summary_file
        puts "FINISHED: $params"
    }

    set end_time [clock format [clock seconds]]
    logwr "End time: $end_time" $summary_file
}




