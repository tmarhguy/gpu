`timescale 1ns/1ps
// DRAW validation: malformed counts must raise error and return to idle.
module tb_drawerr;
 reg clk=0,reset=1;
 always #5 clk=~clk;
 reg [15:0] addr=0; reg [31:0] wdata=0; reg write=0,valid=0;
 wire ready; wire [31:0] rdata;
 pineapple_gpu #(.ASSET("assets/cube/")) dut(.clk(clk),.reset(reset),
  .pix_clk(clk),.pix_reset(reset),
  .addr(addr),.wdata(wdata),.write(write),.read(1'b0),.valid(valid),
  .ready(ready),.rdata(rdata),
  .vblank_start(1'b0),.scan_addr(16'd0),.scan_color(),.display_valid());
 task w(input [15:0] a, input [31:0] d); begin
  @(negedge clk); addr=a; wdata=d; write=1; valid=1;
  @(negedge clk); write=0; valid=0;
 end endtask
 task cmd(input [31:0] c); begin
  @(negedge clk); wait(ready); w(16'h50,c); @(negedge clk); wait(ready); @(negedge clk);
 end endtask
 initial begin
  #103 reset=0; @(negedge clk); wait(ready);
  w(16'h10,5); @(negedge clk); wait(ready);
  cmd(2);
  if(!dut.error) $fatal(1,"count 5 must set error");
  if(dut.state!=0) $fatal(1,"must return to idle");
  $display("PASS drawerr: bad count rejected, back to idle");
  $finish;
 end
 initial begin #1000000; $fatal(1,"drawerr timeout state=%d",dut.state); end
endmodule
