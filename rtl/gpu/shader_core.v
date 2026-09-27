`timescale 1ns/1ps
module shader_core(input clk,reset,start, input [8:0] program_base,
 input [71:0] in0,in1,in2,
 output [5:0] uniform_addr,input [71:0] uniform_data,
 output [15:0] texture_addr,input [11:0] texture_data,
 output reg busy,done,fault,output reg [71:0] out0,out1,out2,
 output reg [31:0] instructions,texture_requests);
 (* rom_style="block" *) reg [31:0] program_mem[0:511];
 initial $readmemh("assets/program.mem",program_mem);
 reg [31:0] ins;
 reg [8:0] pc;
 reg [6:0] steps;
 reg [71:0] regs[0:15];
 reg [71:0] av,bv,cv,result;
 reg signed [35:0] prod[0:3];
 reg [3:0] state;
 wire [5:0] op=ins[31:26];
 wire [3:0] dst=ins[25:22];
 wire [3:0] mask=op==2?ins[21:18]:ins[9:6];
 assign uniform_addr=ins[5:0];
 function [7:0] coord(input signed [17:0] x);
  begin coord=x<0?0:(x>=4096?255:x[11:4]); end
 endfunction
 assign texture_addr={coord(av[35:18]),coord(av[17:0])};
 function [17:0] expand(input [3:0] nib); begin expand={6'b0,nib,nib,nib}; end endfunction
 reg signed [37:0] dot;
 integer i;
 reg signed [17:0] aa,bb,cc;
 always @* begin
  dot=$signed(prod[0])+$signed(prod[1])+$signed(prod[2]);
  if(op==9) dot=dot+$signed(prod[3]);
 end
 always @(posedge clk) begin
  ins<=program_mem[pc]; done<=0;
  if(reset) begin busy<=0; state<=0; fault<=0; instructions<=0; texture_requests<=0; pc<=0; end
  else case(state)
   0: if(start) begin
    regs[0]<=in0; regs[1]<=in1; regs[2]<=in2;
    for(i=3;i<16;i=i+1) regs[i]<=0;
    out0<=0; out1<=0; out2<=0; pc<=program_base; steps<=0; busy<=1; fault<=0; state<=1;
   end
   1: state<=2;
   2: begin av<=regs[ins[21:18]]; bv<=regs[ins[17:14]]; cv<=regs[ins[13:10]]; state<=3; end
   3: begin
    for(i=0;i<4;i=i+1) prod[i]<=$signed(av[i*18+:18])*$signed(bv[i*18+:18]);
    state<=op==15?6:4;
   end
   6: state<=4;
   4: begin
    instructions<=instructions+1'b1;
    for(i=0;i<4;i=i+1) begin
     aa=$signed(av[i*18+:18]); bb=$signed(bv[i*18+:18]); cc=$signed(cv[i*18+:18]);
     case(op)
      1: result[i*18+:18]<=aa;
      2: result[i*18+:18]<=ins[17:0];
      3: result[i*18+:18]<=uniform_data[i*18+:18];
      4: result[i*18+:18]<=aa+bb;
      5: result[i*18+:18]<=aa-bb;
      6: result[i*18+:18]<=prod[i]>>>12;
      7: result[i*18+:18]<=(prod[i]>>>12)+cc;
      8,9: result[i*18+:18]<=dot>>>12;
      10: result[i*18+:18]<=aa<bb?aa:bb;
      11: result[i*18+:18]<=aa>bb?aa:bb;
      12: result[i*18+:18]<=aa<0?0:(aa>4096?4096:aa);
      13: result[i*18+:18]<=aa<bb?4096:0;
      14: result[i*18+:18]<=aa!=0?bb:cc;
      default: result[i*18+:18]<=0;
     endcase
    end
    if(op==15) begin
     result<={18'd4096,expand(texture_data[3:0]),expand(texture_data[7:4]),expand(texture_data[11:8])};
     texture_requests<=texture_requests+1'b1;
    end
    if(op==0 || op>16 || steps==63) begin
     busy<=0; done<=1; fault<=op!=0; state<=0;
    end else if(op==16) begin
     case(ins[1:0]) 0:out0<=av; 1:out1<=av; 2:out2<=av; default:fault<=1; endcase
     pc<=pc+1'b1; steps<=steps+1'b1; state<=1;
    end else state<=5;
   end
   5: begin
    for(i=0;i<4;i=i+1) if(mask[i]) regs[dst][i*18+:18]<=result[i*18+:18];
    pc<=pc+1'b1; steps<=steps+1'b1; state<=1;
   end
   default: state<=0;
  endcase
 end
endmodule
