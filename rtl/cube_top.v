`timescale 1ns/1ps
// Second-asset showcase top: the identical GPU RTL rendering the cube.
// Stage 9 proof that the pipeline is asset-agnostic; see docs/milestones.md.
module cube_top(input clk,cpu_resetn,input btnu,btnd,btnl,btnr,btnc,
 output [3:0] dvi_r,dvi_g,dvi_b,output dvi_hs,dvi_vs,dvi_de,dvi_clk);
 pineapple_top #(.ASSET("assets/cube/"), .INDEX_COUNT(36)) top(
  .clk(clk),.cpu_resetn(cpu_resetn),
  .btnu(btnu),.btnd(btnd),.btnl(btnl),.btnr(btnr),.btnc(btnc),
  .dvi_r(dvi_r),.dvi_g(dvi_g),.dvi_b(dvi_b),
  .dvi_hs(dvi_hs),.dvi_vs(dvi_vs),.dvi_de(dvi_de),.dvi_clk(dvi_clk));
endmodule
