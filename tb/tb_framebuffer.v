`timescale 1ns/1ps
module tb_framebuffer;
 reg clk=0,pclk=0,reset=1,preset=1;
 always #5 clk=~clk;always #19 pclk=~pclk;
 reg we=0,present=0,blank=0;reg [15:0] wa=0,sa=0;reg [11:0] color=0;
 wire done,visible;wire [11:0] pixel;
 render_target dut(.clk(clk),.reset(reset),.pix_clk(pclk),.pix_reset(preset),
 .write_en(we),.write_addr(wa),.write_color(color),.present(present),.present_done(done),
 .vblank_start(blank),.scan_addr(sa),.scan_color(pixel),.display_valid(visible));
 reg oldfront=0,oldblank=0;
 always @(negedge pclk) begin
  if(!preset && dut.front!=oldfront && !oldblank) $fatal(1,"swap outside vblank");
  oldfront=dut.front;
 end
 always @(posedge pclk) oldblank<=blank;
 task writepixel(input [11:0] value);begin
  @(negedge clk);color=value;we=1;@(negedge clk);we=0;
 end endtask
 task swap;begin
  @(negedge clk);present=1;@(negedge clk);present=0;
  repeat(12) @(negedge clk);
  if(done) $fatal(1,"early acknowledgment");
  @(negedge pclk);blank=1;@(negedge pclk);blank=0;
  wait(done);@(negedge clk);repeat(3) @(negedge pclk);
 end endtask
 initial begin
  repeat(4) @(negedge pclk);reset=0;preset=0;
  writepixel(12'habc);swap;
  if(pixel!==12'habc || !visible) $fatal(1,"first present");
  writepixel(12'h123);repeat(4) @(negedge pclk);
  if(pixel!==12'habc) $fatal(1,"back write tears front");
  swap;
  if(pixel!==12'h123) $fatal(1,"second present");
  reset=1;preset=1;repeat(4) @(negedge pclk);
  if(visible) $fatal(1,"reset display validity");
  $display("PASS framebuffer: async clocks, vblank-only swap, ack, front isolation, reset");$finish;
 end
 initial begin #100000;$fatal(1,"framebuffer timeout");end
endmodule
