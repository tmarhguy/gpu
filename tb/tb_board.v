`timescale 1ns/1ps
module tb_board;
    reg clk=0, resetn=0;
    always #5 clk=~clk;
    wire [3:0] r,g,b;
    wire hs,vs,de,pclk;
    bringup_top dut(.clk(clk), .cpu_resetn(resetn), .btnu(1'b0), .btnd(1'b0),
        .btnl(1'b0), .btnr(1'b0), .btnc(1'b0), .dvi_r(r), .dvi_g(g), .dvi_b(b),
        .dvi_hs(hs), .dvi_vs(vs), .dvi_de(de), .dvi_clk(pclk));
    integer i, ex,ey,active=0,hslow=0,vslow=0,blank=0;
    reg [11:0] color;
    initial begin
        #103 resetn=1;
        wait(!dut.reset);
        @(negedge pclk);
        for(i=0;i<800*525*2;i=i+1) begin
            ex=i%800; ey=(i/800)%525;
            if(dut.x !== ex || dut.y !== ey) $fatal(1,"counter mismatch at %d",i);
            color=0;
            if(ex<640 && ey<480) begin
                active=active+1;
                if(ex<160) color=12'hf00;
                else if(ex<320) color=12'h0f0;
                else if(ex<480) color=12'h00f;
                else color=12'hfff;
            end
            if(dut.vblank_start) blank=blank+1;
            @(posedge pclk); #1;
            if({r,g,b} !== color || de !== (ex<640 && ey<480)) $fatal(1,"pixel alignment %d",i);
            if(hs !== !(ex>=656 && ex<752)) $fatal(1,"hsync");
            if(vs !== !(ey>=490 && ey<492)) $fatal(1,"vsync");
            if(!hs) hslow=hslow+1;
            if(!vs) vslow=vslow+1;
            @(negedge pclk);
        end
        if(active!=614400 || hslow!=100800 || vslow!=3200 || blank!=2) $fatal(1,"frame totals");
        resetn=0; #1;
        if(!dut.reset) $fatal(1,"reset assertion");
        repeat(5) @(posedge pclk);
        #1;
        if(dut.x!=0 || dut.y!=0 || de) $fatal(1,"reset did not clear video");
        $display("PASS board: two frames, RGB, porch/sync, blank pulse, reset");
        $finish;
    end
    initial begin #40000000; $fatal(1,"timeout"); end
endmodule
