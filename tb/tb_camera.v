`timescale 1ns/1ps
module tb_camera;
 reg clk=0,reset=1,ready=0;reg [4:0] buttons=0;reg [7:0] key=0;
 wire [4:0] yaw;wire [3:0] pitch;wire [1:0] zoom;wire [2:0] mode;
 always #5 clk=~clk;
 camera_controller dut(.clk(clk),.reset(reset),.buttons(buttons),.key_ready(ready),.key(key),.yaw(yaw),.pitch(pitch),.zoom(zoom),.mode(mode));
 task press(input [7:0] k,input [4:0] b);begin
  @(negedge clk);buttons=b;@(negedge clk);key=k;ready=1;
  @(negedge clk);ready=0;@(negedge clk);buttons=0;repeat(2) @(negedge clk);
 end endtask
 initial begin
  repeat(3) @(negedge clk);reset=0;
  press(8'h1e,1);if(pitch!=5)$fatal(1,"one press must move one step");
  press(8'h0d,16);if(mode!=1)$fatal(1,"center tap");
  press(8'h0d,18);if(zoom!=1 || mode!=1)$fatal(1,"center-down chord must zoom only");
  press(8'h0d,17);if(zoom!=0 || mode!=1)$fatal(1,"center-up chord");
  press(8'h11,4);if(yaw!=31)$fatal(1,"yaw wraps");
  $display("PASS camera: one-step orbit, yaw wrap, center tap, chord zoom");$finish;
 end
endmodule
