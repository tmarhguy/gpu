`timescale 1ns/1ps
module tb_reciprocal;
 reg clk=0,reset=1,start=0;always #5 clk=~clk;
 reg [31:0] n,d;wire busy,done;wire [31:0] q;
 reciprocal dut(.clk(clk),.reset(reset),.start(start),.numerator(n),.denominator(d),.busy(busy),.done(done),.quotient(q));
 integer i;reg [31:0] expected;
 initial begin
  repeat(3) @(negedge clk);reset=0;
  for(i=0;i<100;i=i+1) begin
   n=$random;d=$random;if(i==0)d=0;if(i==1)d=1;if(i==2)begin n=16777216;d=4096;end
   expected=d==0?32'hffffffff:n/d;start=1;@(negedge clk);start=0;wait(done);@(negedge clk);
   if(q!==expected) $fatal(1,"divider %d / %d got %d expected %d",n,d,q,expected);
  end
  $display("PASS reciprocal: 100 divisions, zero, unity, reciprocal scale");$finish;
 end
 initial begin #100000;$fatal(1,"divider timeout");end
endmodule
