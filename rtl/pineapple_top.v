`timescale 1ns/1ps
// P1 demo top: GPU + host + scanout. ASSET selects the packed model;
// the GPU RTL itself is asset-agnostic (see rtl/cube_top.v).
module pineapple_top #(parameter ASSET="assets/packed/", parameter INDEX_COUNT=3216)(
 input clk,cpu_resetn,input btnu,btnd,btnl,btnr,btnc,input RsRx,
 output [3:0] dvi_r,dvi_g,dvi_b,output dvi_hs,dvi_vs,dvi_de,dvi_clk);
 wire pix_clk,pix_reset,gpu_clk;
 clock_reset clocks(.clk(clk),.cpu_resetn(cpu_resetn),.pix_clk(pix_clk),.gpu_clk(gpu_clk),.reset(pix_reset));
 (* ASYNC_REG="TRUE" *) reg [2:0] reset_pipe=7;
 always @(posedge gpu_clk or negedge cpu_resetn)
  if(!cpu_resetn) reset_pipe<=7; else reset_pipe<={reset_pipe[1:0],1'b0};
 wire reset=reset_pipe[2];
 wire [7:0] key;
 wire key_ready;
 wire [4:0] buttons;
 keypad #(.SAMPLE(16)) keys(.clk(gpu_clk),.reset(reset),.btnu(btnu),.btnd(btnd),.btnl(btnl),.btnr(btnr),.btnc(btnc),.rd(key_ready),.kb_data(key),.kb_ready(key_ready),.buttons(buttons));
 wire [4:0] yaw; wire [3:0] pitch; wire [1:0] zoom; wire [2:0] mode;
 camera_controller camera(.clk(gpu_clk),.reset(reset),.buttons(buttons),.key_ready(key_ready),.key(key),.yaw(yaw),.pitch(pitch),.zoom(zoom),.mode(mode));
 wire [15:0] bus_addr; wire [31:0] wdata,rdata; wire write,valid,ready;
 wire host_hold;
 demo_host #(.INDEX_COUNT(INDEX_COUNT)) host(.clk(gpu_clk),.reset(reset),.yaw(yaw),.pitch(pitch),.zoom(zoom),.mode(mode),.hold(host_hold),.addr(bus_addr),.wdata(wdata),.write(write),.valid(valid),.ready(ready));
 wire rx_valid; wire [7:0] rx_data;
 uart_rx rx(.clk(gpu_clk),.reset(reset),.rx(RsRx),.valid(rx_valid),.data(rx_data),.frame_err());
 wire [9:0] x,y;
 wire hs,vs,de,vblank;
 gpu_scanout timing(.pix_clk(pix_clk),.reset(pix_reset),.x(x),.y(y),.hs(hs),.vs(vs),.de(de),.vblank_start(vblank));
 wire image_active=de && y>=60 && y<420;
 wire [9:0] image_y=y-60;
 wire [15:0] scan_addr=image_active?(image_y[9:1]*320+x[9:1]):16'd0;
 wire [11:0] pixel;
 wire display_valid;
 pineapple_gpu #(.ASSET(ASSET)) gpu(.clk(gpu_clk),.reset(reset),.pix_clk(pix_clk),.pix_reset(pix_reset),
 .addr(bus_addr),.wdata(wdata),.write(write),.read(1'b0),.valid(valid),.ready(ready),.rdata(rdata),
 .vblank_start(vblank),.scan_addr(scan_addr),.scan_color(pixel),.display_valid(display_valid),
 .rx_data(rx_data),.rx_valid(rx_valid),.host_hold(host_hold));
 reg hs1,vs1,de1,image1;
 always @(posedge pix_clk) begin hs1<=hs; vs1<=vs; de1<=de; image1<=image_active&&!pix_reset; end
 wire [11:0] rgb=image1&&display_valid?pixel:12'd0;
 dvi_out display(.pix_clk(pix_clk),.r(rgb[11:8]),.g(rgb[7:4]),.b(rgb[3:0]),.hs(hs1),.vs(vs1),.de(de1),
 .dvi_r(dvi_r),.dvi_g(dvi_g),.dvi_b(dvi_b),.dvi_hs(dvi_hs),.dvi_vs(dvi_vs),.dvi_de(dvi_de),.dvi_clk(dvi_clk));
endmodule
