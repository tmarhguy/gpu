`timescale 1ns/1ps
module tb_shader;
 reg clk=0,reset=1,start=0;
 always #5 clk=~clk;
 reg [71:0] in0,in1,in2;
 wire [71:0] out0,out1,out2;
 wire [5:0] ua; wire [15:0] ta; wire [11:0] td;
 wire busy,done,fault;wire [31:0] ins,tex;
 reg [31:0] programs[0:6143];reg [71:0] inputs[0:287],expected[0:287];
 texture_mem tm(.clk(clk),.addr(ta),.data(td));
 shader_core dut(.clk(clk),.reset(reset),.start(start),.program_base(9'd0),.in0(in0),.in1(in1),.in2(in2),
 .uniform_addr(ua),.uniform_data({18'd17,18'd2048,18'h3f000,18'd4096}),.texture_addr(ta),.texture_data(td),
 .busy(busy),.done(done),.fault(fault),.out0(out0),.out1(out1),.out2(out2),.instructions(ins),.texture_requests(tex),
 .prog_we(1'b0),.prog_addr(9'd0),.prog_data(32'd0));
 integer i,j;
 initial begin
  $readmemh("build/shader-programs.mem",programs);$readmemh("build/shader-inputs.mem",inputs);$readmemh("build/shader-expected.mem",expected);
  repeat(3) @(negedge clk);reset=0;
  for(i=0;i<96;i=i+1) begin
   for(j=0;j<64;j=j+1) dut.program_mem[j]=programs[i*64+j];
   in0=inputs[i*3];in1=inputs[i*3+1];in2=inputs[i*3+2];start=1;
   @(negedge clk);start=0;wait(done);@(negedge clk);
   if(fault||out0!==expected[i*3]||out1!==expected[i*3+1]||out2!==expected[i*3+2])
    $fatal(1,"shader case %d expected %h %h %h got %h %h %h",i,expected[i*3],expected[i*3+1],expected[i*3+2],out0,out1,out2);
  end
  for(j=0;j<64;j=j+1) dut.program_mem[j]=32'h040003c0;
  start=1;@(negedge clk);start=0;wait(done);#1;
  if(!fault) $fatal(1,"missing-END watchdog");
  $display("PASS shader: 96 reference programs, every opcode, masks, overflow, texture clamp, watchdog");$finish;
 end
 initial begin #1000000;$fatal(1,"shader timeout");end
endmodule
