`timescale 1ns/1ps
module camera_controller(input clk,reset,input [4:0] buttons,input key_ready,input [7:0] key,
 output reg [4:0] yaw,output reg [3:0] pitch,output reg [1:0] zoom,output reg [2:0] mode);
 reg [4:0] old;
 reg chord;
 wire up=key_ready&&((key==8'h1e)||(key==8'h0d&&buttons[0]));
 wire down=key_ready&&((key==8'h1f)||(key==8'h0d&&buttons[1]));
 always @(posedge clk) begin
  old<=buttons;
  if(reset) begin yaw<=0; pitch<=4; zoom<=0; mode<=0; chord<=0; old<=0; end
  else begin
   if(buttons[4]&&!old[4]) chord<=0;
   if(buttons[4]&&(up||down)) begin
    chord<=1;
    if(up&&zoom!=0) zoom<=zoom-1'b1;
    if(down&&zoom!=3) zoom<=zoom+1'b1;
   end else begin
    if(up&&pitch<8) pitch<=pitch+1'b1;
    if(down&&pitch>0) pitch<=pitch-1'b1;
   end
   if(key_ready && key==8'h11) yaw<=yaw-1'b1;
   if(key_ready && key==8'h10) yaw<=yaw+1'b1;
   if(!buttons[4]&&old[4]&&!chord) mode<=mode==5?0:mode+1'b1;
  end
 end
endmodule
