`timescale 1ns/1ps
// Board-independent, command-driven sequential P1 graphics processor.
module pineapple_gpu #(parameter ASSET="assets/packed/")(
 input clk,reset,pix_clk,pix_reset,
 input [15:0] addr,input [31:0] wdata,input write,read,valid,
 output ready,output reg [31:0] rdata,
 input vblank_start,input [15:0] scan_addr,output [11:0] scan_color,output display_valid,
 input [7:0] rx_data,input rx_valid,output host_hold);
 reg [7:0] state;
 reg [11:0] clear_color;
 reg [13:0] index_count,index_base,offset;
 reg [10:0] vertex_base;
 reg [8:0] vs_base,fs_base;
 reg cull;
 reg [17:0] u0[0:15],u1[0:15],u2[0:15],u3[0:15];
 wire [5:0] uaddr;
 wire [71:0] udata={u3[uaddr[3:0]],u2[uaddr[3:0]],u1[uaddr[3:0]],u0[uaddr[3:0]]};
 (* rom_style="block" *) reg [15:0] index_mem[0:16383];
 (* rom_style="block" *) reg [143:0] vertex_mem[0:2047];
 initial begin $readmemh({ASSET,"indices.mem"},index_mem); $readmemh({ASSET,"vertices.mem"},vertex_mem); end
 reg [15:0] index_data;
 reg [143:0] vertex_data;
 always @(posedge clk) begin
  index_data<=index_mem[index_base+offset];
  vertex_data<=vertex_mem[vertex_base+index_data[10:0]];
 end
 reg shader_start;
 reg [8:0] shader_base;
 reg [71:0] in0,in1,in2;
 wire shader_done,shader_busy,shader_fault;
 wire [71:0] out0,out1,out2;
 wire [15:0] tex_addr;
 wire [11:0] tex_data;
 wire [31:0] instructions,texture_requests;
 wire prog_we; wire [8:0] prog_addr; wire [31:0] prog_data; wire [31:0] prog_loads; wire prog_error;
 texture_mem #(.FILE({ASSET,"texture.mem"})) tex(.clk(clk),.addr(tex_addr),.data(tex_data));
 shader_core shader(.clk(clk),.reset(reset),.start(shader_start),.program_base(shader_base),
  .in0(in0),.in1(in1),.in2(in2),.uniform_addr(uaddr),.uniform_data(udata),
  .texture_addr(tex_addr),.texture_data(tex_data),.busy(shader_busy),.done(shader_done),.fault(shader_fault),
  .out0(out0),.out1(out1),.out2(out2),.instructions(instructions),.texture_requests(texture_requests),
  .prog_we(prog_we),.prog_addr(prog_addr),.prog_data(prog_data));
 // Runtime shader upload commits only while the command state machine is
 // idle, so in-flight DRAWs always execute an intact program.
 shader_loader loader(.clk(clk),.reset(reset),.rx_valid(rx_valid),.rx_data(rx_data),
  .gpu_idle(state==0),.prog_we(prog_we),.prog_addr(prog_addr),.prog_data(prog_data),
  .host_hold(host_hold),.loads(prog_loads),.error(prog_error));
 reg div_start;
 reg [31:0] numerator,denominator;
 wire div_done,div_busy;
 wire [31:0] quotient;
 reciprocal divider(.clk(clk),.reset(reset),.start(div_start),.numerator(numerator),.denominator(denominator),.busy(div_busy),.done(div_done),.quotient(quotient));
 reg [1:0] vertex;
 reg signed [15:0] vx[0:2],vy[0:2];
 // attrs: z (unsigned in positive signed 18 bits), q, uq, vq, normal xyz.
 reg signed [17:0] attr[0:20];
 reg signed [17:0] q;
 reg signed [35:0] px,py,pz,pu,pv;
 wire signed [47:0] screen_x=48'sd160+(($signed(px)*48'sd160)>>>24);
 wire signed [47:0] screen_y=48'sd90-(($signed(py)*48'sd90)>>>24);
 reg signed [31:0] area_a,area_b;
 wire signed [31:0] signed_area=area_a-area_b;
 reg [31:0] inv_area;
 reg raster_start;
 wire raster_busy,raster_done,raster_valid;
 wire [15:0] raster_addr;
 wire signed [31:0] e0,e1,e2;
 wire [31:0] area;
 wire raster_ready=state==20;
 rasterizer raster(.clk(clk),.reset(reset),.start(raster_start),
 .x0(vx[0]),.y0(vy[0]),.x1(vx[1]),.y1(vy[1]),.x2(vx[2]),.y2(vy[2]),
 .ready(raster_ready),.valid(raster_valid),.busy(raster_busy),.done(raster_done),
 .address(raster_addr),.e0(e0),.e1(e1),.e2(e2),.area(area));
 reg [31:0] weight_lo[0:2],weight_mid0[0:2],weight_mid1[0:2];
 reg signed [17:0] ai0,ai1,ai2;
 reg [16:0] w0,w1,w2;
 reg signed [35:0] ap0,ap1,ap2;
 wire signed [37:0] asum=$signed(ap0)+$signed(ap1)+$signed(ap2);
 reg [2:0] component;
 reg signed [17:0] interp[0:6];
 reg [15:0] fragment_addr;
 (* ram_style="block" *) reg [15:0] zmem[0:57599];
 reg [15:0] zread;
 reg [15:0] clear_addr;
 wire [15:0] zaddr=state==1?clear_addr:fragment_addr;
 wire fb_we=state==1||state==31;
 function [3:0] quantize(input signed [17:0] val); begin quantize=val<0?0:(val>=4096?15:val[11:8]); end endfunction
 wire [11:0] rgb={quantize(out0[17:0]),quantize(out0[35:18]),quantize(out0[53:36])};
 wire present=state==40;
 wire present_done;
 render_target target(.clk(clk),.reset(reset),.pix_clk(pix_clk),.pix_reset(pix_reset),
 .write_en(fb_we),.write_addr(zaddr),.write_color(state==1?clear_color:rgb),
 .present(present),.present_done(present_done),.vblank_start(vblank_start),
 .scan_addr(scan_addr),.scan_color(scan_color),.display_valid(display_valid));
 always @(posedge clk) begin
  zread<=zmem[zaddr];
  if(state==1) zmem[zaddr]<=16'hffff;
  else if(state==31) zmem[zaddr]<=interp[0][15:0];
 end
  (* keep="true" *) reg [31:0] frames,cycles,frame_cycles,vertices,triangles,culled,rasterized,fragments,killed,shaded;
 reg error;
 // Serial mod-3 validation for DRAW: bit i of the count weighs 2^i mod 3
 // (1 for even i, 2 for odd i). One bit per cycle keeps this off the critical
 // path; a full DRAW runs millions of cycles, so 14 extra cycles are nothing.
 reg [13:0] draw_count;
 reg [1:0] mod3_acc;
 reg [3:0] mod3_bit;
 wire [2:0] mod3_sum = mod3_acc + (draw_count[mod3_bit] ? (mod3_bit[0] ? 2'd2 : 2'd1) : 2'd0);
 wire [2:0] mod3_next = (mod3_sum >= 3) ? (mod3_sum - 3) : mod3_sum;
 assign ready=(state==0)||read;
 always @* begin
  case(addr)
   16'h0:rdata={30'b0,error,state!=0};
   16'h4:rdata={20'b0,clear_color};
   16'h8:rdata={21'b0,vertex_base};
   16'hc:rdata={18'b0,index_base};
   16'h10:rdata={18'b0,index_count};
   16'h14:rdata={23'b0,vs_base};
   16'h18:rdata={23'b0,fs_base};
   16'h20:rdata=frames;
   16'h24:rdata=frame_cycles;
   16'h28:rdata=vertices;
   16'h2c:rdata=triangles;
   16'h30:rdata=culled;
   16'h34:rdata=rasterized;
   16'h38:rdata=fragments;
   16'h3c:rdata=killed;
   16'h40:rdata=shaded;
   16'h44:rdata=texture_requests;
   16'h48:rdata=instructions;
   16'h4c:rdata=prog_loads;
   default:rdata=0;
  endcase
 end
 integer i;
 always @(posedge clk) begin
  shader_start<=0; div_start<=0; raster_start<=0;
  if(reset) begin
   state<=0; clear_color<=12'h013; index_count<=0; index_base<=0; vertex_base<=0;
   vs_base<=0; fs_base<=64; cull<=0; error<=0; offset<=0;
   frames<=0; cycles<=0; frame_cycles<=0; vertices<=0; triangles<=0; culled<=0; rasterized<=0;
   fragments<=0; killed<=0; shaded<=0;
  end else begin
   cycles<=cycles+1'b1;
   case(state)
    0: if(valid && write) begin
     if(addr[15:8]==1) begin
      case(addr[3:2]) 0:u0[addr[7:4]]<=wdata[17:0]; 1:u1[addr[7:4]]<=wdata[17:0];
       2:u2[addr[7:4]]<=wdata[17:0]; 3:u3[addr[7:4]]<=wdata[17:0]; endcase
     end else case(addr)
      4:clear_color<=wdata[11:0]; 8:vertex_base<=wdata[10:0]; 12:index_base<=wdata[13:0];
      16:index_count<=wdata[13:0]; 20:vs_base<=wdata[8:0]; 24:fs_base<=wdata[8:0]; 28:cull<=wdata[0];
       16'h50:case(wdata)
        1:begin clear_addr<=0; state<=1; end
        2:begin
         offset<=0; vertex<=0;
         if(index_count<3 || {1'b0,index_base}+index_count>16384) begin error<=1; state<=0; end
         else begin draw_count<=index_count; mod3_acc<=0; mod3_bit<=0; state<=42; end
        end
        3:state<=40;
        default:error<=1;
       endcase
      default:begin end
     endcase
    end
    1: if(clear_addr==57599) state<=0; else clear_addr<=clear_addr+1'b1;
    42: begin
     mod3_acc<=mod3_next[1:0];
     if(mod3_bit==13) begin
      if(mod3_next==0) state<=2;
      else begin error<=1; state<=0; end
     end else mod3_bit<=mod3_bit+1'b1;
    end
    2: state<=3;
    3: state<=4;
    4: begin
     if(index_data>=2048 || {1'b0,vertex_base}+index_data>=2048) begin error<=1; state<=0; end
     else begin
      in0<={18'd4096,vertex_data[53:0]}; in1<={18'd0,vertex_data[107:54]}; in2<={36'd0,vertex_data[143:108]};
      shader_base<=vs_base; shader_start<=1; state<=5;
     end
    end
    5: if(shader_done) begin
     vertices<=vertices+1'b1;
     if(shader_fault) begin error<=1; state<=0; end
     else if($signed(out0[71:54])<512) begin culled<=culled+1'b1; state<=35; end
     else begin numerator<=32'd16777216; denominator<={14'd0,out0[71:54]}; div_start<=1; state<=6; end
    end
    6: if(div_done) begin q<=quotient>131071?18'd131071:quotient[17:0]; state<=7; end
    7: begin
     px<=$signed(out0[17:0])*q; py<=$signed(out0[35:18])*q; pz<=$signed(out0[53:36])*q;
     pu<=$signed(out2[17:0])*q; pv<=$signed(out2[35:18])*q; state<=8;
    end
    8: begin
     if(screen_x < -1024 || screen_x>1023 || screen_y < -1024 || screen_y>1023) begin culled<=culled+1'b1; state<=35; end
     else begin
      vx[vertex]<=screen_x[15:0]; vy[vertex]<=screen_y[15:0];
      attr[vertex*7]<=pz<0?0:((pz>>>8)>65535?65535:pz>>>8);
      attr[vertex*7+1]<=q; attr[vertex*7+2]<=pu>>>12; attr[vertex*7+3]<=pv>>>12;
      attr[vertex*7+4]<=out1[17:0]; attr[vertex*7+5]<=out1[35:18]; attr[vertex*7+6]<=out1[53:36];
      if(vertex==2) state<=9; else begin vertex<=vertex+1'b1; offset<=offset+1'b1; state<=2; end
     end
    end
    9: begin
     area_a<=($signed(vx[1])-vx[0])*($signed(vy[2])-vy[0]);
     area_b<=($signed(vy[1])-vy[0])*($signed(vx[2])-vx[0]); state<=13;
    end
    13: begin
     triangles<=triangles+1'b1;
     if(signed_area==0 || (cull && signed_area<0)) begin culled<=culled+1'b1; state<=35; end
     else if(signed_area<0) begin
      vx[1]<=vx[2]; vx[2]<=vx[1]; vy[1]<=vy[2]; vy[2]<=vy[1];
      for(i=0;i<7;i=i+1) begin attr[7+i]<=attr[14+i]; attr[14+i]<=attr[7+i]; end
      state<=10;
     end else state<=10;
    end
    10: begin numerator<=32'd1073741824; denominator<=(signed_area<0?-signed_area:signed_area)<<2; div_start<=1; state<=11; end
    11: if(div_done) begin inv_area<=quotient; raster_start<=1; rasterized<=rasterized+1'b1; state<=12; end
    12: state<=20;
    20: begin
     if(raster_valid) begin
      fragment_addr<=raster_addr; fragments<=fragments+1'b1;
      weight_lo[0]<=e0[15:0]*inv_area[15:0]; weight_mid0[0]<=e0[31:16]*inv_area[15:0]; weight_mid1[0]<=e0[15:0]*inv_area[31:16];
      weight_lo[1]<=e1[15:0]*inv_area[15:0]; weight_mid0[1]<=e1[31:16]*inv_area[15:0]; weight_mid1[1]<=e1[15:0]*inv_area[31:16];
      weight_lo[2]<=e2[15:0]*inv_area[15:0]; weight_mid0[2]<=e2[31:16]*inv_area[15:0]; weight_mid1[2]<=e2[15:0]*inv_area[31:16];
      state<=21;
     end else if(!raster_busy) state<=35;
    end
    21: begin w0<=(weight_lo[0]+(weight_mid0[0]<<16)+(weight_mid1[0]<<16))>>14;
     w1<=(weight_lo[1]+(weight_mid0[1]<<16)+(weight_mid1[1]<<16))>>14;
     w2<=(weight_lo[2]+(weight_mid0[2]<<16)+(weight_mid1[2]<<16))>>14; component<=0; state<=22; end
    22: begin
     ai0<=attr[component]; ai1<=attr[7+component]; ai2<=attr[14+component]; state<=36;
    end
    36: begin
     ap0<=$signed({1'b0,w0})*ai0; ap1<=$signed({1'b0,w1})*ai1; ap2<=$signed({1'b0,w2})*ai2; state<=23;
    end
    23: begin
     interp[component]<=asum>>>16;
     if(component==6) state<=24; else begin component<=component+1'b1; state<=22; end
    end
    24: if(interp[0][15:0]>=zread || interp[1]<=0) begin killed<=killed+1'b1; state<=20; end
     else begin numerator<=32'd16777216; denominator<={14'd0,interp[1]}; div_start<=1; state<=25; end
    25: if(div_done) begin q<=quotient>131071?18'd131071:quotient[17:0]; state<=26; end
    26: begin pu<=interp[2]*q; pv<=interp[3]*q; state<=27; end
    27: begin
     in0<={18'd4096,18'd0,pv[29:12],pu[29:12]};
     in1<={18'd0,interp[6],interp[5],interp[4]};
     in2<={18'd4096,{6'b0,interp[0][15:4]},{6'b0,interp[0][15:4]},{6'b0,interp[0][15:4]}};
     shader_base<=fs_base; shader_start<=1; state<=30;
    end
    30: if(shader_done) begin
     if(shader_fault) begin error<=1; state<=0; end
     else begin shaded<=shaded+1'b1; state<=31; end
    end
    31: state<=20;
    35: begin
     // offset currently points at whichever corner was last submitted.
     if((offset-vertex)+3>=index_count) state<=0;
     else begin offset<=offset-vertex+3; vertex<=0; state<=2; end
    end
    40:state<=41;
    41:if(present_done) begin frames<=frames+1'b1; frame_cycles<=cycles; cycles<=0; state<=0; end
    default:state<=0;
   endcase
  end
 end
endmodule
