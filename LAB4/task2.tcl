#!/bin/tclsh
if {$argc != 1} {
    puts "Usage: tclsh task2.tcl <log_file>"
    exit 1
}

set filename [lindex $argv 0]

set design_name ""
set lib_file ""
set operating_cond ""

set fp [open $filename r]
while {[gets $fp line] >= 0} {

    # Extract design name
    if {[regexp {^Design\s*:\s*(\S+)} $line -> dname]} {
        set design_name $dname
    }

    # Extract library file name
    if {[regexp {File:\s*(\S+)} $line -> lib]} {
        set lib_file $lib
    }

    # Extract operating condition
    if {[regexp {^Operating Conditions:\s*(\S+)} $line -> op]} {
        set operating_cond $op
    }
}
close $fp

puts "Design Name          : $design_name"
puts "Library File Used    : $lib_file"
puts "Operating Conditions : $operating_cond"
