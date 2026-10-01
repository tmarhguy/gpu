`timescale 1ns/1ps
// 8N1 UART receiver, 16x oversample. `rx` is asynchronous and synchronized
// here; `valid`/`frame_err` pulse for one cycle. Parameterized for the
// 50 MHz gpu_clk domain (DIV = 27); any CLK_HZ/BAUD that keeps DIV >= 8 works.
module uart_rx #(parameter CLK_HZ=50000000, parameter BAUD=115200)(
 input clk, reset, rx,
 output reg valid, output reg [7:0] data, output reg frame_err);
 localparam integer DIV=CLK_HZ/(BAUD*16);
 reg [1:0] sync;
 reg busy;
 reg [15:0] divcnt;
 reg [9:0] cnt;      // 16x ticks since the start edge
 reg [7:0] shift;
 wire tick=divcnt==DIV-1;
 always @(posedge clk) begin
  sync<={sync[0],rx};
  valid<=1'b0; frame_err<=1'b0;
  if(reset) begin busy<=1'b0; divcnt<=0; cnt<=0; shift<=0; data<=0; end
  else if(!busy) begin
   if(!sync[1]) begin busy<=1'b1; divcnt<=0; cnt<=0; end
  end else if(tick) begin
   divcnt<=0; cnt<=cnt+1'b1;
   case(cnt)
    10'd8: if(sync[1]) busy<=1'b0;                 // false start edge
    10'd24,10'd40,10'd56,10'd72,10'd88,10'd104,10'd120,10'd136:
     shift<={sync[1],shift[7:1]};                 // d0..d7, LSB first
    10'd152: begin                                // stop bit
     busy<=1'b0;
     if(!sync[1]) frame_err<=1'b1;                // framing error: drop byte
     else begin data<=shift; valid<=1'b1; end
    end
    default: begin end
   endcase
  end else divcnt<=divcnt+1'b1;
 end
endmodule
