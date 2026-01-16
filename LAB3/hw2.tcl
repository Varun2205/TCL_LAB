#!/bin/tclsh

proc terminate {msg} {  # Fixed typo: "terminate" not "teminate"
    puts stderr "ERROR: $msg"
    exit 1
}

proc extract_all_delays {fname} {  # ADDED: missing procedure
    set fp [open $fname r]
    set delays [list]
    set total_delay 0.0
    
    while {[gets $fp line] >= 0} {
        # Extract any decimal numbers that look like delay values
        set numbers [regexp -all -inline {[\-\d]+\.[\d]+} $line]
        foreach num $numbers {
            lappend delays $num
            set total_delay [expr {$total_delay + $num}]
        }
    }
    
    close $fp
    return [list $delays $total_delay]
}

proc parse_timing_report {fname} {
    set fp [open $fname r]
    set startpoint ""
    set endpoint ""
    set slack ""

    # Read file line by line
    while {[gets $fp line] >= 0} {
        # Match Startpoint
        if {$startpoint eq "" && [regexp {^\s*Startpoint:\s+(\S+)} $line -> sp]} {
            set startpoint $sp
        }

        # Match Endpoint
        if {[regexp {^ *Endpoint: ([^ ]+)} $line -> ep]} {
            set endpoint $ep
        }

        # Match Slack
        if {[regexp {slack\s*\((\w+)\)\s*([\-\d\.]+)} $line -> status sl]} {
            set slack $sl
        }
    }

    # Close file
    close $fp

    # Create a dictionary
    set results [dict create startpoint $startpoint endpoint $endpoint slack $slack]
    return $results
}

proc sum_positive_delays {fname} {  # Fixed: removed $ before parameter
    set result [extract_all_delays $fname]
    set delays [lindex $result 0]

    set positive_total 0.0
    foreach delay $delays {
        if {$delay > 0} {
            set positive_total [expr {$positive_total + $delay}]
        }
    }

    return $positive_total
}

# ------------------------MAIN----------------------------------------------
if {[llength $argv] != 1} {
    terminate "Usage: tclsh parse_timing_report.tcl <filename.log>"
}

set report [lindex $argv 0]
set r [parse_timing_report $report]
puts "Startpoint: [dict get $r startpoint]"
puts "Endpoint: [dict get $r endpoint]"
puts "Slack: [dict get $r slack]"

# Usage - Fixed variable name
set positive_sum [sum_positive_delays $report]  
puts "Sum of only positive delays: $positive_sum"
