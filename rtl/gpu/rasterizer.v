`timescale 1ns/1ps
// Pixel-center top-left edge walker. Inputs must have positive signed area.
module rasterizer(input clk,reset,start,
 input signed [15:0] x0,y0,x1,y1,x2,y2,
 input ready, output valid,output reg busy,done,
 output [15:0] address,output reg signed [31:0] e0,e1,e2,
 output reg [31:0] area);
 reg signed [15:0] x,y,minx,maxx,maxy;
 reg signed [31:0] row0,row1,row2,dx0,dx1,dx2,dy0,dy1,dy2;
 reg tl0,tl1,tl2;
 reg [1:0] setup_phase;
 reg signed [31:0] init0,init1,init2;
 function signed [15:0] lo(input signed [15:0] a,b,c); begin lo=a<b?(a<c?a:c):(b<c?b:c); end endfunction
 function signed [15:0] hi(input signed [15:0] a,b,c); begin hi=a>b?(a>c?a:c):(b>c?b:c); end endfunction
 function signed [31:0] edge_fn(input signed [15:0] ax,ay,bx,by,px,py);
  begin edge_fn=(bx-ax)*(2*py+1-2*ay)*2-(by-ay)*(2*px+1-2*ax)*2; end
 endfunction
 function tl(input signed [15:0] ax,ay,bx,by); begin tl=(by<ay)||((by==ay)&&(bx>ax)); end endfunction
 wire signed [15:0] lx=lo(x0,x1,x2)<0?16'sd0:lo(x0,x1,x2);
 wire signed [15:0] ly=lo(y0,y1,y2)<0?16'sd0:lo(y0,y1,y2);
 wire signed [15:0] hx=hi(x0,x1,x2)>319?16'sd319:hi(x0,x1,x2);
 wire signed [15:0] hy=hi(y0,y1,y2)>179?16'sd179:hi(y0,y1,y2);
 assign valid=busy && setup_phase==0 && (e0>0||(e0==0&&tl0)) && (e1>0||(e1==0&&tl1)) && (e2>0||(e2==0&&tl2));
 assign address=y*320+x;
 always @(posedge clk) begin
  done<=0;
  if(reset) begin busy<=0; setup_phase<=0; end
  else if(start && !busy) begin
   x<=lx; minx<=lx; y<=ly; maxx<=hx; maxy<=hy;
   
   
   
   dx0<=-4*(y2-y1); dy0<=4*(x2-x1);
   dx1<=-4*(y0-y2); dy1<=4*(x0-x2);
   dx2<=-4*(y1-y0); dy2<=4*(x1-x0);
   tl0<=tl(x1,y1,x2,y2); tl1<=tl(x2,y2,x0,y0); tl2<=tl(x0,y0,x1,y1);
   area<=4*((x1-x0)*(y2-y0)-(y1-y0)*(x2-x0));
   setup_phase<=1;
   if(lx>hx||ly>hy) begin busy<=0; done<=1; setup_phase<=0; end else busy<=1;
  end else if(setup_phase==1) begin
   init0<=edge_fn(x1,y1,x2,y2,x,y); init1<=edge_fn(x2,y2,x0,y0,x,y); init2<=edge_fn(x0,y0,x1,y1,x,y); setup_phase<=2;
  end else if(setup_phase==2) begin
   e0<=init0;row0<=init0;e1<=init1;row1<=init1;e2<=init2;row2<=init2;setup_phase<=0;
  end else if(busy && (!valid || ready)) begin
   if(x==maxx) begin
    if(y==maxy) begin busy<=0; done<=1; end
    else begin
     x<=minx; y<=y+1'b1;
     row0<=row0+dy0; e0<=row0+dy0;
     row1<=row1+dy1; e1<=row1+dy1;
     row2<=row2+dy2; e2<=row2+dy2;
    end
   end else begin x<=x+1'b1; e0<=e0+dx0; e1<=e1+dx1; e2<=e2+dx2; end
  end
 end
endmodule
