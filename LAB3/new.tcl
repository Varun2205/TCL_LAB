#!/usr/bin/env tclsh

# ============================================================
# Argument handling
# ============================================================
if {$argc != 1} {
    puts "Usage: tclsh timing_analyzer.tcl <timing_report.log>"
    exit 1
}

set REPORT_FILE [lindex $argv 0]

if {![file exists $REPORT_FILE]} {
    puts "ERROR: File not found: $REPORT_FILE"
    exit 1
}

# ============================================================
# 1. parse_timing_report
#    Extract startpoint, endpoint, slack
# ============================================================
proc parse_timing_report {filename} {
    set startpoint ""
    set endpoint ""
    set slack ""

    set fp [open $filename r]
    while {[gets $fp line] >= 0} {
        if {[regexp {^Startpoint:\s+(\S+)} $line -> sp]} {
            set startpoint $sp
        }
        if {[regexp {^Endpoint:\s+(\S+)} $line -> ep]} {
            set endpoint $ep
        }
        if {[regexp {slack\s+\(.*\)\s+([-0-9.]+)} $line -> sl]} {
            set slack $sl
        }
    }
    close $fp

    return [list $startpoint $endpoint $slack]
}

# ============================================================
# 2. extract_cell_delays
#    Extract instance, cell type, delay
# ============================================================
proc extract_cell_delays {filename} {
    set cells {}
    set in_table 0

    set fp [open $filename r]
    while {[gets $fp line] >= 0} {

        if {[string match "*Point*Incr*Path*" $line]} {
            set in_table 1
            continue
        }

        if {$in_table && [string match "*data arrival time*" $line]} {
            set in_table 0
            continue
        }

        if {$in_table} {
            # Example:
            # AES_CORE/U2551/Y (AO221X1_HVT)  0.12 150.55 r
            if {[regexp {(\S+)/\S+\s+\(([^)]+)\)\s+([0-9.]+)} \
                $line -> inst celltype delay]} {

                lappend cells [list $inst $celltype $delay]
            }
        }
    }
    close $fp
    return $cells
}

# ============================================================
# 3. analyze_by_cell_type
# ============================================================
proc analyze_by_cell_type {cell_list} {
    array set delay_sum {}
    array set count {}

    foreach cell $cell_list {
        lassign $cell inst type delay
        set delay_sum($type) [expr {[info exists delay_sum($type)] ? \
                                    $delay_sum($type) + $delay : $delay}]
        incr count($type)
    }
    return [list [array get delay_sum] [array get count]]
}

# ============================================================
# 4. analyze_by_hierarchy
# ============================================================
proc analyze_by_hierarchy {cell_list} {
    array set hier_delay {}

    foreach cell $cell_list {
        lassign $cell inst type delay
        set module [lindex [split $inst "/"] 0]
        set hier_delay($module) [expr {[info exists hier_delay($module)] ? \
                                       $hier_delay($module) + $delay : $delay}]
    }
    return [array get hier_delay]
}

# ============================================================
# 5. find_slowest_cells
# ============================================================
proc find_slowest_cells {cell_list N} {
    set sorted [lsort -real -decreasing -index 2 $cell_list]
    return [lrange $sorted 0 [expr {$N - 1}]]
}

# ============================================================
# 6. check_timing_violations
# ============================================================
proc check_timing_violations {slack threshold} {
    if {$slack < $threshold} {
        return "VIOLATION"
    }
    return "PASS"
}

# ============================================================
# 7. generate_timing_summary
# ============================================================
proc generate_timing_summary {start end slack status \
                              celltype_data celltype_count \
                              hier_data slow_cells} {

    puts "================ TIMING SUMMARY ================"
    puts "Startpoint : $start"
    puts "Endpoint   : $end"
    puts "Slack (ns) : $slack"
    puts "Status     : $status"
    puts ""

    array set ct_delay $celltype_data
    array set ct_count $celltype_count

    puts "---- Delay by Cell Type ----"
    foreach type [lsort [array names ct_delay]] {
        puts [format "%-15s Count=%3d  Delay=%.3f" \
              $type $ct_count($type) $ct_delay($type)]
    }

    puts ""
    puts "---- Delay by Hierarchy ----"
    array set hd $hier_data
    foreach mod [lsort [array names hd]] {
        puts [format "%-20s %.3f" $mod $hd($mod)]
    }

    puts ""
    puts "---- Slowest Cells ----"
    foreach cell $slow_cells {
        lassign $cell inst type delay
        puts [format "%-45s %-15s %.3f" $inst $type $delay]
    }
    puts "==============================================="
}

# ============================================================
# 8. calculate_max_frequency
# ============================================================
proc calculate_max_frequency {clock_period slack} {
    set eff_period [expr {$clock_period - $slack}]
    if {$eff_period <= 0} {
        return "Infinity"
    }
    return [format "%.2f" [expr {1000.0 / $eff_period}]]
}

# ============================================================
# Main Flow
# ============================================================
lassign [parse_timing_report $REPORT_FILE] START END SLACK

set CELLS [extract_cell_delays $REPORT_FILE]

lassign [analyze_by_cell_type $CELLS] CT_DELAY CT_COUNT
set HIER_DELAY [analyze_by_hierarchy $CELLS]
set SLOWEST [find_slowest_cells $CELLS 5]

set STATUS [check_timing_violations $SLACK 0.0]
set FMAX   [calculate_max_frequency 2000.0 $SLACK]

generate_timing_summary \
    $START $END $SLACK $STATUS \
    $CT_DELAY $CT_COUNT \
    $HIER_DELAY $SLOWEST

puts ""
puts "Estimated Max Frequency: $FMAX MHz"
puts ""

