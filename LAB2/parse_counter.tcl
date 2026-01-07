#!/usr/bin/tclsh

if {$argc == 0} {
    puts "Error: Please provide Verilog filename"
    puts "Usage: tclsh parse_counter.tcl <filename>"
    exit 1
}

set filename [lindex $argv 0]

if {![file exists $filename]} {
    puts "Error: File '$filename' not found!"
    exit 1
}

set line_count 0
set module_name ""
set reg_vars ""
set always_count 0

set fp [open $filename r]

while {[gets $fp line] != -1} {
    incr line_count
    set line [string trim $line]
    
    if {$line eq ""} { continue }
    
    # Extract module name
    if {[string match "module *" $line]} {
        set words [split $line " "]
        foreach word $words {
            if {$word != "module" && $word != ""} {
                set module_name [string trim $word "(){};,"]
                break
            }
        }
    }
    
    # Extract reg variables - FIXED REGEX
    if {[regexp {^\s*reg} $line]} {
        # Remove everything after //
        set clean_line [lindex [split $line "//"] 0]
        # Look for reg followed by optional range and variable name
        if {[regexp {reg\s*(?:\[.*?\])?\s*(\w+)} $clean_line match var]} {
            if {$reg_vars eq ""} {
                set reg_vars $var
            } else {
                if {[lsearch [split $reg_vars ","] $var] == -1} {
                    set reg_vars "$reg_vars, $var"
                }
            }
        }
    }
    
    # Count always blocks
    if {[string match "*always*" $line]} {
        incr always_count
    }
}

close $fp

puts "Parsing Results for: $filename"
puts "========================================"
puts "a. Number of lines: $line_count"
puts "b. Module name: $module_name"
puts "c. Reg variables: $reg_vars"
puts "d. Number of always blocks: $always_count"
puts ""

# Create testbench - FIXED ESCAPING ISSUES
if {$module_name ne ""} {
    set tb_filename "tb_${module_name}.v"
    set fp [open $tb_filename w]
    
    # Use list for each line to avoid command substitution
    puts $fp "// Testbench for $module_name"
    puts $fp [list `timescale 1ns/1ps]
    puts $fp ""
    puts $fp [list module tb_${module_name};]
    puts $fp "    reg clk;"
    puts $fp "    reg rst;"
    puts $fp "    reg mode;"
    puts $fp "    wire \[3:0\] count;"
    puts $fp ""
    puts $fp "    $module_name dut ("
    puts $fp "        .clk(clk),"
    puts $fp "        .rst(rst),"
    puts $fp "        .mode(mode),"
    puts $fp "        .count(count)"
    puts $fp "    );"
    puts $fp ""
    puts $fp "    always #5 clk = ~clk;"
    puts $fp ""
    puts $fp "    initial begin"
    puts $fp "        clk = 0;"
    puts $fp "        rst = 1;"
    puts $fp "        mode = 0;"
    puts $fp "        #10 rst = 0;"
    puts $fp ""
    puts $fp "        // Test up counting"
    puts $fp "        mode = 0;"
    puts $fp "        repeat(20) #10;"
    puts $fp ""
    puts $fp "        // Test down counting"
    puts $fp "        mode = 1;"
    puts $fp "        repeat(20) #10;"
    puts $fp ""
    puts $fp "        // Test reset during counting"
    puts $fp "        mode = 0;"
    puts $fp "        #30 rst = 1;"
    puts $fp "        #10 rst = 0;"
    puts $fp "        #40;"
    puts $fp ""
    puts $fp "        \$finish;"
    puts $fp "    end"
    puts $fp ""
    puts $fp "    initial begin"
    puts $fp "        \$dumpfile(\"${module_name}.vcd\");"
    puts $fp "        \$dumpvars(0, tb_${module_name});"
    puts $fp "    end"
    puts $fp ""
    puts $fp "endmodule"
    
    close $fp
    
    puts "Testbench created: $tb_filename"
} else {
    puts "Error: Could not extract module name"
}
