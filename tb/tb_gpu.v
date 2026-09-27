`timescale 1ns/1ps
module tb_gpu;
 reg clk=0,pclk=0,reset=1;
 always #5 clk=~clk;
 always #20 pclk=~pclk;
 wire [15:0] addr; wire [31:0] wd,rd;
 wire wr,valid,ready;
 reg [2:0] mode=0;
 reg [4:0] yaw=0;
 wire [11:0] pixel;
 wire visible;
 reg [11:0] blank_count=0;
 always @(posedge pclk) blank_count<=blank_count+1'b1;
`ifdef PINE_TEST_SHOWCASE
 localparam ASSET="assets/packed/";
 localparam COUNT=3216;
`else
 localparam ASSET="assets/cube/";
 localparam COUNT=36;
`endif
 demo_host #(.INDEX_COUNT(COUNT)) host(.clk(clk),.reset(reset),.yaw(yaw),.pitch(4'd4),.zoom(2'd0),.mode(mode),.addr(addr),.wdata(wd),.write(wr),.valid(valid),.ready(ready));
 pineapple_gpu #(.ASSET(ASSET)) dut(.clk(clk),.reset(reset),.pix_clk(pclk),.pix_reset(reset),
 .addr(addr),.wdata(wd),.write(wr),.read(1'b0),.valid(valid),.ready(ready),.rdata(rd),
 .vblank_start(blank_count==0),.scan_addr(16'd0),.scan_color(pixel),.display_valid(visible));
 integer f,i,cycles=0,argmode,argyaw;
 reg [1023:0] filename;
 always @(posedge clk) begin
  cycles<=cycles+1;
  if(dut.error) $fatal(1,"GPU fault state=%d offset=%d",dut.state,dut.offset);
 end
 initial begin
  if($value$plusargs("MODE=%d",argmode)) mode=argmode;
  if($value$plusargs("YAW=%d",argyaw)) yaw=argyaw;
  if(!$value$plusargs("OUT=%s",filename)) filename="build/rtl-frame.mem";
  #103 reset=0;
  wait(dut.frames==1);
  if(!visible) $fatal(1,"presentation didn't enable display");
  f=$fopen(filename,"w");
  for(i=0;i<57600;i=i+1) $fdisplay(f,"%03x",dut.target.bank1[i]);
  $fclose(f);
  $display("PASS GPU frame cycles=%d triangles=%d fragments=%d depth_killed=%d shaded=%d instructions=%d",cycles,dut.triangles,dut.fragments,dut.killed,dut.shaded,dut.instructions);
  $finish;
 end
 initial begin #1000000000; $fatal(1,"GPU timeout state=%d offset=%d",dut.state,dut.offset); end
endmodule
