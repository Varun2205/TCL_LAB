// Testbench for sync_up_down_counter
`timescale 1ns/1ps

module tb_sync_up_down_counter
    reg clk;
    reg rst;
    reg mode;
    wire [3:0] count;

    sync_up_down_counter dut (
        .clk(clk),
        .rst(rst),
        .mode(mode),
        .count(count)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        mode = 0;
        #10 rst = 0;

        // Test up counting
        mode = 0;
        repeat(20) #10;

        // Test down counting
        mode = 1;
        repeat(20) #10;

        // Test reset during counting
        mode = 0;
        #30 rst = 1;
        #10 rst = 0;
        #40;

        $finish;
    end

    initial begin
        $dumpfile("sync_up_down_counter.vcd");
        $dumpvars(0, tb_sync_up_down_counter);
    end

endmodule
