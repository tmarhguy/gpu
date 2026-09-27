`timescale 1ns/1ps
// Four immutable RGB444 texels per 48-bit word; bit-slice addressing.
module texture_mem #(parameter FILE="assets/packed/texture.mem")
(input clk,input [15:0] addr,output reg [11:0] data);
 (* rom_style="block" *) reg [47:0] mem[0:16383];
 initial $readmemh(FILE,mem);
 reg [47:0] word;
 reg [1:0] lane;
 always @(posedge clk) begin
  word<=mem[addr[15:2]]; lane<=addr[1:0];
  case(lane)
   0:data<=word[11:0]; 1:data<=word[23:12]; 2:data<=word[35:24]; default:data<=word[47:36];
  endcase
 end
endmodule
