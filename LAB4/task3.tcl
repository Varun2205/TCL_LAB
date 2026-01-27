#!/bin/tclsh
if {$argc != 1} {
    puts "Usage: tclsh task3.tcl <log_file>"
    exit 1
}

set filename [lindex $argv 0]

set cell_internal 0.0
set net_switching 0.0
set total_dynamic 0.0
set cell_leakage 0.0

set fp [open $filename r]
while {[gets $fp line] >= 0} {

    if {[regexp {Cell Internal Power\s*=\s*([\d\.]+)} $line -> val]} {
        set cell_internal $val
    }

    if {[regexp {Net Switching Power\s*=\s*([\d\.]+)} $line -> val]} {
        set net_switching $val
    }

    if {[regexp {Total Dynamic Power\s*=\s*([\d\.]+)} $line -> val]} {
        set total_dynamic $val
    }

    if {[regexp {Cell Leakage Power\s*=\s*([\d\.]+)} $line -> val]} {
        set cell_leakage $val
    }
}
close $fp

# Total power calculation (Dynamic + Leakage)
set total_power [expr {$total_dynamic + $cell_leakage}]

puts "Cell Internal Power  : $cell_internal uW"
puts "Net Switching Power  : $net_switching uW"
puts "Total Dynamic Power  : $total_dynamic uW"
puts "Cell Leakage Power   : $cell_leakage uW"
puts "--------------------------------------"
puts "Total Power          : $total_power uW"
