#!/bin/tclsh
if {$argc != 1} {
    puts "Usage: tclsh task1.tcl <log_file>"
    exit 1
}

set filename [lindex $argv 0]

set total_lines 0
set non_empty_lines 0

set fp [open $filename r]
while {[gets $fp line] >= 0} {
    incr total_lines
    if {[string trim $line] ne ""} {
        incr non_empty_lines
    }
}
close $fp

puts "Total lines      : $total_lines"
puts "Non-empty lines  : $non_empty_lines"
