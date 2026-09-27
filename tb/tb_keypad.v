`timescale 1ns/1ps
module tb_keypad;
    reg clk=0, reset=1;
    reg [4:0] raw=0;
    always #5 clk=~clk;
    wire [7:0] data;
    wire ready;
    wire [4:0] buttons;
    integer count=0;
    keypad #(.SAMPLE(2), .STABLE_N(3), .REPEAT_AFTER(8), .REPEAT_RATE(4)) dut(
        .clk(clk), .reset(reset), .btnu(raw[0]), .btnd(raw[1]), .btnl(raw[2]),
        .btnr(raw[3]), .btnc(raw[4]), .rd(ready), .kb_data(data), .kb_ready(ready), .buttons(buttons));
    always @(posedge clk) if(!reset && ready) count=count+1;
    task cycles(input integer n); begin repeat(n) @(negedge clk); end endtask
    initial begin
        cycles(4); reset=0;
        raw=1; cycles(2); raw=0; cycles(20);
        if(count!=0) $fatal(1,"bounce leaked");
        raw=16; cycles(100);
        if(count!=1 || data!=8'h0d || buttons!=16) $fatal(1,"center repeats or lost");
        raw=0; cycles(20); count=0;
        raw=1; cycles(100);
        if(count<3 || data!=8'h1e) $fatal(1,"arrow repeat missing");
        raw=17; cycles(20);
        if(buttons!=17) $fatal(1,"chord levels missing");
        raw=0; cycles(20); count=0; cycles(40);
        if(count!=0 || buttons!=0) $fatal(1,"release");
        $display("PASS keypad: bounce, center one-shot, arrow repeat, chord levels");
        $finish;
    end
    initial begin #100000; $fatal(1,"timeout"); end
endmodule
