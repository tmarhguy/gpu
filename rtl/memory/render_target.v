`timescale 1ns/1ps
module render_target(input clk,reset,pix_clk,pix_reset,
 input write_en,input [15:0] write_addr,input [11:0] write_color,
 input present,output present_done,input vblank_start,
 input [15:0] scan_addr,output [11:0] scan_color,output reg display_valid);
 (* ram_style="block" *) reg [11:0] bank0[0:57599],bank1[0:57599];
 reg front=0,request=0,ack=0;
 (* ASYNC_REG="TRUE" *) reg [1:0] req_sync=0,ack_sync=0;
 reg back=1;
 reg pending=0;
 reg [11:0] pixel0,pixel1;
 assign scan_color=front?pixel1:pixel0;
 assign present_done=pending && ack_sync[1]==request;
 always @(posedge clk) begin
  ack_sync<={ack_sync[0],ack};
  if(reset) begin request<=0; pending<=0; back<=1; ack_sync<=0; end
  else begin
   if(present && !pending) begin request<=~request; pending<=1; end
   if(present_done) begin pending<=0; back<=~back; end
   if(write_en && !pending) begin
    if(back) bank1[write_addr]<=write_color; else bank0[write_addr]<=write_color;
   end
  end
 end
 always @(posedge pix_clk) begin
  pixel0<=bank0[scan_addr]; pixel1<=bank1[scan_addr];
  req_sync<={req_sync[0],request};
  if(pix_reset) begin front<=0; ack<=0; req_sync<=0; display_valid<=0; end
  else if(vblank_start && req_sync[1]!=ack) begin
   front<=~front; ack<=req_sync[1]; display_valid<=1;
  end
 end
endmodule
