`timescale 1ns/1ps
// Per-frame PineBus program. INDEX_COUNT comes from the top (asset selection);
// the camera table is shared by all assets.
module demo_host #(parameter INDEX_COUNT=3216)(input clk,reset,
 input [4:0] yaw,input [3:0] pitch,input [1:0] zoom,input [2:0] mode,
 output reg [15:0] addr,output reg [31:0] wdata,output write,valid,input ready);
 (* rom_style="block" *) reg [17:0] cameras[0:18431];
 initial $readmemh("assets/camera.mem",cameras);
 reg [14:0] camera_base;
 reg [4:0] component;
 reg [17:0] value;
 reg [4:0] state;
 reg [2:0] shader_mode;
 always @(posedge clk) value<=cameras[camera_base+component];
 assign write=1;
 assign valid=state==1||state==2||state==3||state==4||state==5||state==6||state==10||state==12||state==14||state==16||state==18;
 always @* begin
  addr=0; wdata=0;
  case(state)
   1:begin addr=16'h10; wdata=INDEX_COUNT; end
   2:begin addr=16'h4; wdata=12'h013; end
   3:begin addr=16'h140; wdata=1638; end
   4:begin addr=16'h144; wdata=3277; end
   5:begin addr=16'h148; wdata=1638; end
   6:begin addr=16'h14c; wdata=0; end
   10:begin addr=16'h100+component*4; wdata={14'd0,value}; end
   12:begin addr=16'h18; wdata=(shader_mode+1)*64; end
   14:begin addr=16'h50; wdata=1; end
   16:begin addr=16'h50; wdata=2; end
   18:begin addr=16'h50; wdata=3; end
   default:begin end
  endcase
 end
 always @(posedge clk) begin
  if(reset) begin state<=1; component<=0; camera_base<=0; shader_mode<=0; end
  else case(state)
   1,2,3,4,5,6: if(ready) state<=state+1'b1;
   7:begin camera_base<=((zoom*288)+(pitch*32)+yaw)*16; component<=0; shader_mode<=mode; state<=8; end
   8:state<=9;
   9:state<=10;
   10:if(ready) begin
    if(component==15) state<=12; else begin component<=component+1'b1; state<=8; end
   end
   12:if(ready) state<=14;
   14:if(ready) state<=15;
   15:if(ready) state<=16;
   16:if(ready) state<=17;
   17:if(ready) state<=18;
   18:if(ready) state<=19;
   19:if(ready) state<=7;
   default:state<=1;
  endcase
 end
endmodule
