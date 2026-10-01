`timescale 1ns/1ps
// Runtime shader upload. Frame: "PINE" magic, base/count as LE16 words,
// count payload words LE, one checksum byte (sum of every post-magic byte
// mod 256). Payload stages into LUTRAM while the GPU keeps rendering the old
// program; on a good checksum the host is held, GPU idle is awaited, and the
// staged words commit to instruction RAM in count cycles, then hold releases.
// A bad checksum or range drops the frame with program RAM untouched, and a
// ~335 ms gap mid-frame aborts back to idle. `loads` counts committed
// frames; `error` sticks until the next good commit or reset.
module shader_loader #(parameter GAP_MAX=24'hffffff)(
 input clk, reset,
 input rx_valid, input [7:0] rx_data,
 input gpu_idle,
 output reg prog_we, output reg [8:0] prog_addr, output reg [31:0] prog_data,
 output reg host_hold,
 output reg [31:0] loads, output reg error);
 (* ram_style="block" *) reg [31:0] stage[0:511];
 // Synchronous SDP ports: the open nextpnr-xilinx flow cannot pack LUTRAM,
 // so both staging ports are clocked to land in a RAMB block.
 reg stage_we; reg [8:0] stage_waddr; reg [31:0] stage_wdata;
 reg [8:0] stage_raddr; reg [31:0] stage_q;
 always @(posedge clk) if(stage_we) stage[stage_waddr]<=stage_wdata;
 always @(posedge clk) stage_q<=stage[stage_raddr];
 reg [3:0] state;
 reg [15:0] base;
 reg [9:0] total;       // validated word count (1..512); 10 bits so 512 compares cleanly
 reg [8:0] idx,ridx;
 reg [1:0] sub;
 reg [7:0] sum;
 reg [31:0] word;
 reg [23:0] gap;        // cycles since last byte, mid-frame only
 localparam M0=0,M1=1,M2=2,M3=3,B0=4,B1=5,C0=6,C1=7,PAY=8,SUM=9,HOLD=10,COPYA=11,COPYB=12;
 wire midframe=state==M1||state==M2||state==M3||state==B0||state==B1||state==C0||state==C1||state==PAY||state==SUM;
 always @(posedge clk) begin
  prog_we<=1'b0; stage_we<=1'b0;
  if(reset) begin
   state<=M0; base<=0; total<=0; idx<=0; ridx<=0; sub<=0; sum<=0; word<=0; gap<=0;
   stage_we<=1'b0; stage_waddr<=0; stage_wdata<=0; stage_raddr<=0;
   prog_addr<=0; prog_data<=0; host_hold<=1'b0; loads<=0; error<=1'b0;
  end else if(midframe && !rx_valid && gap==GAP_MAX) begin
   error<=1'b1; state<=M0;   // truncated frame: give up, program RAM untouched
  end else case(state)
   // Magic hunt: exact-match only, so line noise just fails to advance.
   // Any inter-byte gap past GAP_MAX aborts (M0 true-idle excepted).
   M0: if(rx_valid && rx_data==8'h50) begin gap<=0; state<=M1; end
   M1: if(rx_valid) begin
    gap<=0;
    if(rx_data==8'h49) state<=M2; else state<=M0;
   end else gap<=gap+1'b1;
   M2: if(rx_valid) begin
    gap<=0;
    if(rx_data==8'h4e) state<=M3; else state<=M0;
   end else gap<=gap+1'b1;
   M3: if(rx_valid) begin
    gap<=0;
    if(rx_data==8'h45) begin sum<=0; sub<=0; state<=B0; end
    else state<=M0;
   end else gap<=gap+1'b1;
   B0: if(rx_valid) begin base<={8'd0,rx_data}; sum<=sum+rx_data; gap<=0; state<=B1; end
    else gap<=gap+1'b1;
   B1: if(rx_valid) begin base<={rx_data,base[7:0]}; sum<=sum+rx_data; gap<=0; state<=C0; end
    else gap<=gap+1'b1;
   C0: if(rx_valid) begin total<={2'b0,rx_data}; sum<=sum+rx_data; gap<=0; state<=C1; end
    else gap<=gap+1'b1;
   C1: if(rx_valid) begin
    gap<=0;
    begin : range_check
     reg [9:0] cnt;
     cnt={rx_data[1:0],total[7:0]};
     sum<=sum+rx_data;
     // Range-check before touching anything: count>=1, base+count<=512.
     if(cnt==0 || {1'b0,base}+{7'b0,cnt}>17'd512) begin error<=1'b1; state<=M0; end
     else begin total<=cnt; idx<=0; sub<=0; word<=0; state<=PAY; end
    end
   end else gap<=gap+1'b1;
   PAY: if(rx_valid) begin
    gap<=0;
    sum<=sum+rx_data;
    case(sub)
     0: begin word[7:0]<=rx_data; sub<=1; end
     1: begin word[15:8]<=rx_data; sub<=2; end
     2: begin word[23:16]<=rx_data; sub<=3; end
     3: begin
      stage_we<=1'b1; stage_waddr<=idx; stage_wdata<={rx_data,word[23:0]}; sub<=0;
      if({1'b0,idx}+1'b1==total) state<=SUM; else idx<=idx+1'b1;
     end
    endcase
   end else gap<=gap+1'b1;
   SUM: if(rx_valid) begin
    if(rx_data==sum) begin host_hold<=1'b1; state<=HOLD; end
    else begin error<=1'b1; state<=M0; end
   end else gap<=gap+1'b1;
   HOLD: if(gpu_idle) begin ridx<=0; stage_raddr<=0; state<=COPYA; end
   COPYA: state<=COPYB;   // staged word lands in stage_q this cycle
   COPYB: begin
    prog_we<=1'b1; prog_addr<=base[8:0]+ridx; prog_data<=stage_q;
    if({1'b0,ridx}+1'b1==total) begin
     host_hold<=1'b0; loads<=loads+1'b1; error<=1'b0; state<=M0;
    end else begin ridx<=ridx+1'b1; stage_raddr<=ridx+1'b1; state<=COPYA; end
   end
   default: state<=M0;
  endcase
 end
endmodule
