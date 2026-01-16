#!/bin/tclsh

# 1. parse_timing_report: Extracts key metrics (slack, startpoint, endpoint)
proc parse_timing_report {fname} {
    set fp [open $fname r]
    set startpoint ""
    set endpoint ""
    set slack ""
    
    while {[gets $fp line] >= 0} {
        if {[regexp {Startpoint:\s+([^\s\(]+)} $line -> sp]} {
            set startpoint $sp
        }
        if {[regexp {Endpoint:\s+([^\s\(]+)} $line -> ep]} {
            set endpoint $ep
        }
        if {[regexp {slack\s*\((\w+)\)\s*([\-\d\.]+)} $line -> status sl]} {
            set slack $sl
        }
    }
    close $fp
    
    return [dict create startpoint $startpoint endpoint $endpoint slack $slack]
}

# 2. extract_cell_delays: Parses all cells and calculates delays
proc extract_cell_delays {fname} {
    set fp [open $fname r]
    set cells [list]
    set total_delay 0.0
    set in_path_section 0
    
    while {[gets $fp line] >= 0} {
        if {[regexp {Point.*Incr.*Path} $line]} {
            set in_path_section 1
            continue
        }
        if {[regexp {data arrival time} $line]} {
            set in_path_section 0
        }
        
        if {$in_path_section} {
            if {[regexp {([A-Z_]+/[\w/]+)\s+\(([A-Z0-9]+_[A-Z0-9]+)\)\s+([\d\.]+)} $line -> instance cell_type delay]} {
                lappend cells [list $instance $cell_type $delay]
                set total_delay [expr {$total_delay + $delay}]
            }
        }
    }
    close $fp
    
    return [list $cells $total_delay]
}

# 3. analyze_by_cell_type: Groups delays by cell type
proc analyze_by_cell_type {cells} {
    set cell_types [dict create]
    
    foreach cell $cells {
        set cell_type [lindex $cell 1]
        set delay [lindex $cell 2]
        
        if {![dict exists $cell_types $cell_type]} {
            dict set cell_types $cell_type [list 1 $delay $delay $delay]
        } else {
            set stats [dict get $cell_types $cell_type]
            set count [lindex $stats 0]
            set total [lindex $stats 1]
            set min_delay [lindex $stats 2]
            set max_delay [lindex $stats 3]
            
            incr count
            set total [expr {$total + $delay}]
            if {$delay < $min_delay} {set min_delay $delay}
            if {$delay > $max_delay} {set max_delay $delay}
            
            dict set cell_types $cell_type [list $count $total $min_delay $max_delay]
        }
    }
    
    return $cell_types
}

# 4. analyze_by_hierarchy: Shows delay contribution by module
proc analyze_by_hierarchy {cells} {
    set hierarchy [dict create]
    
    foreach cell $cells {
        set instance [lindex $cell 0]
        set delay [lindex $cell 2]
        
        if {$instance ne "" && [regexp {^([A-Z_]+)/} $instance -> module]} {
            if {![dict exists $hierarchy $module]} {
                dict set hierarchy $module [list 1 $delay]
            } else {
                set stats [dict get $hierarchy $module]
                set count [lindex $stats 0]
                set total [lindex $stats 1]
                
                incr count
                set total [expr {$total + $delay}]
                dict set hierarchy $module [list $count $total]
            }
        }
    }
    
    return $hierarchy
}

# 5. find_slowest_cells: Identifies the top N critical cells
proc find_slowest_cells {cells {top_n 5}} {
    set sorted_cells [lsort -decreasing -real -index 2 $cells]
    return [lrange $sorted_cells 0 [expr {$top_n - 1}]]
}

# 6. check_timing_violations: Automated checking against configurable thresholds
proc check_timing_violations {metrics cell_types {slack_threshold 0.0} {max_cell_delay 0.5}} {
    set violations [list]
    
    set slack [dict get $metrics slack]
    if {$slack < $slack_threshold} {
        lappend violations "Slack violation: $slack < $slack_threshold"
    }
    
    dict for {cell_type stats} $cell_types {
        set max_delay [lindex $stats 3]
        if {$max_delay > $max_cell_delay} {
            lappend violations "$cell_type has max delay $max_delay > $max_cell_delay"
        }
    }
    
    return $violations
}

# 7. generate_timing_summary: Creates comprehensive reports
proc generate_timing_summary {metrics cells cell_types hierarchy violations} {
    puts "\n=== TIMING SUMMARY ==="
    puts "Startpoint: [dict get $metrics startpoint]"
    puts "Endpoint: [dict get $metrics endpoint]"
    puts "Slack: [dict get $metrics slack]"
    
    puts "\n--- Cell Statistics ---"
    puts "Total cells: [llength $cells]"
    
    puts "\n--- Cell Type Analysis ---"
    dict for {cell_type stats} $cell_types {
        set count [lindex $stats 0]
        set total [lindex $stats 1]
        set avg [expr {$total / $count}]
        puts "$cell_type: $count cells, avg delay: [format "%.3f" $avg]"
    }
    
    puts "\n--- Hierarchy Analysis ---"
    dict for {module stats} $hierarchy {
        set count [lindex $stats 0]
        set total [lindex $stats 1]
        puts "$module: $count cells, total delay: [format "%.3f" $total]"
    }
    
    puts "\n--- Timing Violations ---"
    if {[llength $violations] > 0} {
        foreach violation $violations {
            puts "VIOLATION: $violation"
        }
    } else {
        puts "No violations"
    }
}

# 8. calculate_max_frequency: Determines maximum achievable frequency
proc calculate_max_frequency {slack clock_period} {
    if {$slack >= 0} {
        set effective_period [expr {$clock_period - $slack}]
        set max_freq [expr {1000.0 / $effective_period}]
        return [format "%.2f MHz" $max_freq]
    }
    return "Cannot calculate (negative slack)"
}

# Main execution
if {[llength $argv] != 1} {
    puts stderr "Usage: tclsh $argv0 <timing_report.log>"
    exit 1
}

set report [lindex $argv 0]

# Execute all functions
set metrics [parse_timing_report $report]

set cell_data [extract_cell_delays $report]
set cells [lindex $cell_data 0]

set cell_types [analyze_by_cell_type $cells]

set hierarchy [analyze_by_hierarchy $cells]

set slowest_cells [find_slowest_cells $cells]

set violations [check_timing_violations $metrics $cell_types]

# Get clock period for frequency calculation
set fp [open $report r]
set clock_period 0
while {[gets $fp line] >= 0} {
    if {[regexp {clock CLK.*?\s+(\d+\.\d+)\s+(\d+\.\d+)} $line -> incr total]} {
        if {$total > 0 && $clock_period == 0} {
            set clock_period $total
            break
        }
    }
}
close $fp

set max_freq [calculate_max_frequency [dict get $metrics slack] $clock_period]

# Generate summary
generate_timing_summary $metrics $cells $cell_types $hierarchy $violations

# Additional outputs
puts "\n--- Top 5 Slowest Cells ---"
foreach cell [lrange $slowest_cells 0 4] {
    set instance [lindex $cell 0]
    set cell_type [lindex $cell 1]
    set delay [lindex $cell 2]
    puts "$instance ($cell_type): [format "%.3f" $delay]"
}

puts "\n--- Maximum Frequency ---"
puts $max_freq
