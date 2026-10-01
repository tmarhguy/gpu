`timescale 1ns/1ps
// UART receiver + runtime shader loader tests: byte reception, framing and
// false-start handling, staged commit, idle gating, checksum/range/gap
// rejection, and an end-to-end wired upload.
module tb_uart;
 reg clk=0,reset=1;
 always #10 clk=~clk;   // 50 MHz, like gpu_clk
 // --- uart_rx under test ---
 reg rx=1;
 wire uvalid,uerr; wire [7:0] udata;
 uart_rx dut_rx(.clk(clk),.reset(reset),.rx(rx),.valid(uvalid),.data(udata),.frame_err(uerr));
 reg saw_valid,saw_err; reg [7:0] last_data;
 always @(posedge clk) if(uvalid) begin saw_valid<=1'b1; last_data<=udata; end
 always @(posedge clk) if(uerr) saw_err<=1'b1;
 localparam BIT=8640;   // 27*16 cycles at 20 ns
 task send(input [7:0] b, input stopbit); integer k; begin
  saw_valid=0; saw_err=0;
  rx=0; #BIT;
  for(k=0;k<8;k=k+1) begin rx=b[k]; #BIT; end
  rx=stopbit; #BIT; rx=1; #(BIT*2);
 end endtask
 // --- loader under test (direct byte feed) ---
 reg lvalid=0; reg [7:0] ldata=0; reg idle=1;
 wire pwe,phold; wire [8:0] paddr; wire [31:0] pdata;
 wire [31:0] loads; wire lerr;
 shader_loader dut_ld(.clk(clk),.reset(reset),.rx_valid(lvalid),.rx_data(ldata),
  .gpu_idle(idle),.prog_we(pwe),.prog_addr(paddr),.prog_data(pdata),
  .host_hold(phold),.loads(loads),.error(lerr));
 reg [31:0] ram[0:511]; integer i;
 always @(posedge clk) if(pwe) ram[paddr]<=pdata;

 reg [7:0] sum;
 task put(input [7:0] b); begin
  @(negedge clk); ldata=b; lvalid=1; sum=sum+b; @(negedge clk); lvalid=0;
 end endtask
 task frame(input [15:0] base, input [15:0] count); begin
  put(8'h50); put(8'h49); put(8'h4e); put(8'h45); sum=0;  // magic excluded
  put(base[7:0]); put(base[15:8]); put(count[7:0]); put(count[15:8]);
 end endtask
 task pword(input [31:0] w); begin
  put(w[7:0]); put(w[15:8]); put(w[23:16]); put(w[31:24]);
 end endtask
 // --- gap-timeout instance (short fuse) ---
 reg tvalid=0; reg [7:0] tdata=0;
 wire thold; wire [31:0] tloads; wire terr,twe; wire [8:0] taddr; wire [31:0] tpdata;
 shader_loader #(.GAP_MAX(100)) dut_to(.clk(clk),.reset(reset),.rx_valid(tvalid),.rx_data(tdata),
  .gpu_idle(1'b1),.prog_we(twe),.prog_addr(taddr),.prog_data(tpdata),
  .host_hold(thold),.loads(tloads),.error(terr));
 // --- wired chain: uart_rx -> loader ---
 reg wrx=1; wire wvalid; wire [7:0] wdata;
 wire cwe,chold; wire [8:0] caddr; wire [31:0] cpdata; wire [31:0] cloads; wire cerr;
 uart_rx chain_rx(.clk(clk),.reset(reset),.rx(wrx),.valid(wvalid),.data(wdata),.frame_err());
 shader_loader chain_ld(.clk(clk),.reset(reset),.rx_valid(wvalid),.rx_data(wdata),
  .gpu_idle(1'b1),.prog_we(cwe),.prog_addr(caddr),.prog_data(cpdata),
  .host_hold(chold),.loads(cloads),.error(cerr));
 reg [31:0] cram[0:511];
 always @(posedge clk) if(cwe) cram[caddr]<=cpdata;
 task wsend(input [7:0] b); integer k; begin
  wrx=0; #BIT;
  for(k=0;k<8;k=k+1) begin wrx=b[k]; #BIT; end
  wrx=1; #BIT; #(BIT*2);
 end endtask
 initial begin
  for(i=0;i<512;i=i+1) begin ram[i]=0; cram[i]=0; end
  #105; reset=0; repeat(2) @(negedge clk);
  // 1. uart_rx bytes, incl. back-to-back extremes.
  send(8'ha5,1);
  if(!saw_valid||last_data!==8'ha5) $fatal(1,"rx a5");
  send(8'h00,1); if(!saw_valid||last_data!==8'h00) $fatal(1,"rx 00");
  send(8'hff,1); if(!saw_valid||last_data!==8'hff) $fatal(1,"rx ff");
  // 2. framing error: bad stop bit drops the byte.
  send(8'h3c,0);
  if(!saw_err) $fatal(1,"stop-bit error not flagged");
  if(saw_valid) $fatal(1,"bad-stop byte leaked");
  // 3. false-start glitch then a real byte still lands.
  rx=0; #(BIT/4); rx=1; #(BIT*4);
  send(8'h69,1);
  if(!saw_valid||last_data!==8'h69) $fatal(1,"post-glitch byte");
  if(saw_err) $fatal(1,"glitch misflagged");
  // 4. good loader frame: base 64, 3 words.
  frame(16'd64,16'd3);
  if(phold) $fatal(1,"hold during staging");
  if(pwe) $fatal(1,"write during staging");
  pword(32'h11111111); pword(32'h22222222); pword(32'h33333333);
  put(sum);
  wait(phold);
  if(loads!==0) $fatal(1,"loads early");
  wait(!phold); repeat(2) @(negedge clk);
  if(loads!==1) $fatal(1,"loads=%d",loads);
  if(lerr) $fatal(1,"error stuck after good commit");
  if(ram[64]!==32'h11111111||ram[65]!==32'h22222222||ram[66]!==32'h33333333)
   $fatal(1,"commit data %h %h %h",ram[64],ram[65],ram[66]);
  if(ram[63]!==0||ram[67]!==0) $fatal(1,"commit overrun");
  // 5. idle gating: commit waits for gpu_idle.
  idle=0;
  frame(16'd0,16'd1); pword(32'hdeadbeef); put(sum);
  repeat(10) @(negedge clk);
  if(!phold) $fatal(1,"hold must persist while busy");
  if(loads!==1) $fatal(1,"committed while busy");
  idle=1; wait(!phold); repeat(2) @(negedge clk);
  if(ram[0]!==32'hdeadbeef||loads!==2) $fatal(1,"post-idle commit");
  // 6. bad checksum: RAM untouched, error sticks, next good frame clears it.
  frame(16'd70,16'd1); pword(32'hcafef00d); put(sum+1);
  repeat(4) @(negedge clk);
  if(!lerr) $fatal(1,"checksum miss not flagged");
  if(loads!==2) $fatal(1,"bad frame committed");
  if(ram[70]!==0) $fatal(1,"bad frame wrote RAM");
  frame(16'd70,16'd1); pword(32'hcafef00d); put(sum);
  wait(!phold); repeat(2) @(negedge clk);
  if(lerr) $fatal(1,"good frame did not clear error");
  if(ram[70]!==32'hcafef00d||loads!==3) $fatal(1,"recovery commit");
  // 7. range rejects: overrun, zero count, base past the end. No hold, no write.
  frame(16'd500,16'd20); repeat(4) @(negedge clk);
  if(!lerr||phold||loads!==3) $fatal(1,"overrun accepted");
  frame(16'd0,16'd0); repeat(4) @(negedge clk);
  if(!lerr||loads!==3) $fatal(1,"zero count accepted");
  frame(16'd512,16'd1); repeat(4) @(negedge clk);
  if(!lerr||loads!==3) $fatal(1,"base 512 accepted");
  if(phold) $fatal(1,"hold leaked on reject");
  // 8. gap timeout on the short-fuse instance.
  @(negedge clk); tdata=8'h50; tvalid=1; @(negedge clk); tvalid=0;
  @(negedge clk); tdata=8'h49; tvalid=1; @(negedge clk); tvalid=0;
  repeat(150) @(negedge clk);
  if(!terr) $fatal(1,"gap timeout did not fire");
  if(thold||tloads!==0) $fatal(1,"timeout side effects");
  // 9. wired end-to-end: 2-word frame over the actual UART line.
  // base 192, words 11111111/22222222, sum=c0+02+44+88=0x8e.
  wsend(8'h50); wsend(8'h49); wsend(8'h4e); wsend(8'h45);
  wsend(8'hc0); wsend(8'h00); wsend(8'h02); wsend(8'h00);
  wsend(8'h11); wsend(8'h11); wsend(8'h11); wsend(8'h11);
  wsend(8'h22); wsend(8'h22); wsend(8'h22); wsend(8'h22);
  wsend(8'h8e);
  wait(cloads==1); repeat(2) @(negedge clk);
  if(cerr) $fatal(1,"wired frame error");
  if(cram[192]!==32'h11111111||cram[193]!==32'h22222222) $fatal(1,"wired data");
  $display("PASS uart: bytes, framing, glitch, staged commit, idle gate, checksum, range, gap, wired upload");
  $finish;
 end
 initial begin #200000000; $fatal(1,"uart timeout"); end
endmodule
