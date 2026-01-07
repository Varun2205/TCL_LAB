// 4-bit Synchronous Up-Down Counter
module sync_up_down_counter(
    input clk,
    input rst,
    input mode,
    output reg [3:0] count
);

reg [3:0] counter;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        counter <= 4'b0000;
    end
    else if (mode == 1'b0) begin
        counter <= counter + 1'b1;
    end
    else begin
        counter <= counter - 1'b1;
    end
end

always @(posedge clk) begin
    count <= counter;
end

endmodule
