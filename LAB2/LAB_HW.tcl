# Simple parser for Verilog file
set filename "sync_up_down_counter.v"
if {![file exists $filename]} {
    puts "Error: File not found"
    exit 1
}

set fp [open $filename r]
set lines [split [read $fp] "\n"]
close $fp

# Initialize counters
set line_count 0
set module_name ""
set reg_vars {}
set always_blocks 0
set in_module 0


foreach line $lines {
    incr line_count
    set line [string trim $line]
    
    # Skip comments and empty lines
    if {$line == "" || [string match "//*" $line]} {
        continue
    }
    
    # Find module
    if {[string first "module " $line] == 0} {
        set words [split $line " "]
        foreach word $words {
            if {$word != "module" && $word != "" && $module_name == ""} {
                # Remove any trailing characters
                set module_name [string trim $word " \t\n\r\f\v();#"]
                break
            }
        }
        set in_module 1
    }
    
    # Check for endmodule
    if {[string first "endmodule" $line] >= 0} {
        set in_module 0
    }
    
    # Only process if inside module
    if {$in_module} {
        # Find reg declarations
        if {[string first "reg " $line] >= 0 || [string first "\treg " $line] >= 0} {
            # Remove "reg" keyword
            set clean_line [string map {"reg " "" "\treg " ""} $line]
            
            # Remove any [x:y] patterns
            while {[set start [string first "\[" $clean_line]] >= 0} {
                set end [string first "\]" $clean_line]
                if {$end > $start} {
                    set clean_line "[string range $clean_line 0 [expr {$start - 1}]] [string range $clean_line [expr {$end + 1}] end]"
                }
                set clean_line [string trim $clean_line]
            }
            
            # Split by commas and semicolons
            set parts [split $clean_line ";,"]
            foreach part $parts {
                set part [string trim $part]
                if {$part != ""} {
                    # Remove any assignment
                    set equal_pos [string first "=" $part]
                    if {$equal_pos >= 0} {
                        set part [string range $part 0 [expr {$equal_pos - 1}]]
                        set part [string trim $part]
                    }
                    
                    # Remove any size specifications
                    set colon_pos [string first ":" $part]
                    if {$colon_pos >= 0} {
                        set part [string range $part 0 [expr {$colon_pos - 1}]]
                        set part [string trim $part]
                    }
                    
                    if {$part != "" && [lsearch $reg_vars $part] < 0} {
                        lappend reg_vars $part
                    }
                }
            }
        }
        
        # Count always blocks
        if {[string first "always @" $line] >= 0 || 
            [string first "always begin" $line] >= 0 ||
            [string first "always" $line] == 0} {
            incr always_blocks
        }
    }
}

# Print output
puts "Analysis Results for: $filename"
puts "a. Number of lines: $line_count"
puts "b. Module name: $module_name"
puts "c. Reg variables found ([llength $reg_vars] total):"
foreach var [lsort $reg_vars] {
    puts "   $var"
}
puts "d. Number of always blocks: $always_blocks"


puts "Parsing Results for: $filename"
puts "========================================"
puts "a. Number of lines: $line_count"
puts "b. Module name: $module_name"
puts "c. Reg variables: $reg_vars"
puts "d. Number of always blocks: $always_blocks"
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
    puts $fp "endmodule"
    
    close $fp
} else {
	puts "No module found"
}  
