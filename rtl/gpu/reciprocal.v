`timescale 1ns/1ps
// Unsigned restoring divider. Fixed 32-cycle latency; denominator zero saturates.
module reciprocal(input clk,reset,start,input [31:0] numerator,denominator,
 output reg busy,done, output reg [31:0] quotient);
 reg [31:0] dividend, divisor, result;
 reg [32:0] remainder;
 reg [5:0] count;
 wire [32:0] trial={remainder[31:0],dividend[31]};
 wire take=trial >= {1'b0,divisor};
 always @(posedge clk) begin
  done<=0;
  if(reset) begin busy<=0; quotient<=0; end
  else if(start && !busy) begin
   if(denominator==0) begin quotient<=32'hffffffff; done<=1; end
   else begin busy<=1; dividend<=numerator; divisor<=denominator; result<=0; remainder<=0; count<=0; end
  end else if(busy) begin
   remainder<=take?trial-{1'b0,divisor}:trial;
   dividend<=dividend<<1; result<={result[30:0],take}; count<=count+1'b1;
   if(count==31) begin quotient<={result[30:0],take}; busy<=0; done<=1; end
  end
 end
endmodule
