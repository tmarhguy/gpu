`timescale 1ns/1ps
module tb_rasterizer;
 reg clk=0,reset=1,start=0,ready=0;
 always #5 clk=~clk;
 reg signed [15:0] x0,y0,x1,y1,x2,y2;
 wire valid,busy,done;wire [15:0] addr;wire signed [31:0] e0,e1,e2;wire [31:0] area;
 reg [15:0] coords[0:143],counts[0:23],expected[0:16383];
 reg [31:0] random=1234;
 integer i,pos=0,count=0;
 reg stalled=0;reg [15:0] held;
 rasterizer dut(.clk(clk),.reset(reset),.start(start),.x0(x0),.y0(y0),.x1(x1),.y1(y1),.x2(x2),.y2(y2),
 .ready(ready),.valid(valid),.busy(busy),.done(done),.address(addr),.e0(e0),.e1(e1),.e2(e2),.area(area));
 always @(negedge clk) begin random<={random[30:0],random[31]^random[21]^random[1]^random[0]}; ready<=random[0];end
 always @(posedge clk) if(!reset) begin
  if(stalled && (!valid || addr!==held)) $fatal(1,"backpressure stability");
  stalled<=valid&&!ready; held<=addr;
  if(valid&&ready) begin
   if(addr!==expected[pos]) $fatal(1,"raster fragment %d got %d expected %d",pos,addr,expected[pos]);
   pos=pos+1;count=count+1;
  end
 end
 initial begin
  $readmemh("build/raster-coords.mem",coords);$readmemh("build/raster-counts.mem",counts);$readmemh("build/raster-expected.mem",expected);
  repeat(3) @(negedge clk); reset=0;
  for(i=0;i<24;i=i+1) begin
   x0=coords[i*6];y0=coords[i*6+1];x1=coords[i*6+2];y1=coords[i*6+3];x2=coords[i*6+4];y2=coords[i*6+5];count=0;
   start=1;@(negedge clk);start=0;wait(done);@(negedge clk);
   if(count!=counts[i]) $fatal(1,"raster triangle %d count %d expected %d",i,count,counts[i]);
  end
  $display("PASS raster: shared edge, viewport clipping, 24 triangles, randomized backpressure");$finish;
 end
 initial begin #2000000;$fatal(1,"raster timeout");end
endmodule
