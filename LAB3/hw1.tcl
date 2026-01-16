#!/bin/tclsh

proc terminate {msg} {
    puts stderr "ERROR: $msg"
    exit 1
}

proc parse_timing_report {fname} {
    if {![file exists $fname]} {
        terminate "File $fname does not exist."
    }

    set fp [open $fname r]
    set startpoint ""
    set endpoint ""
    set slack ""

    while {[gets $fp line] >= 0} {
        # Match Startpoint
        if {[regexp {^\s*Startpoint:\s+(\S+)} $line -> sp]} {
            set startpoint $sp
        }

        # Match Endpoint
        if {[regexp {^\s*Endpoint:\s+(\S+)} $line -> ep]} {
            set endpoint $ep
        }
    }

    close $fp

    # Create and return a dictionary
    return [dict create startpoint $startpoint endpoint $endpoint]
}

# ------------------------MAIN----------------------------------------------
if {[llength $argv] != 1} {
    terminate "Usage: tclsh parse_timing_report.tcl <filename.log>"
}

set report [lindex $argv 0]
set r [parse_timing_report $report]

puts "Startpoint : [dict get $r startpoint]"
puts "Endpoint   : [dict get $r endpoint]"

