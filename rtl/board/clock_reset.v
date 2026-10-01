`timescale 1ns/1ps
// 100 MHz E3 -> gpu_clk 50 MHz (div/2) + pix_clk 25 MHz (div/4), each BUFG.
// Proven on silicon (pineapple 50.36, cube 60.88 MHz post-route) but fragile by
// construction: fabric-divided clocks carry duty/jitter the MMCM would remove,
// and 50.36 vs 50 MHz target is ~0.7% margin. Kept deliberately because the
// installed FOSS flow (Yosys -> nextpnr-xilinx -> Project X-Ray) has no MMCM
// path; moving to Vivado/MMCM is the first timing-robustness upgrade and is
// purely a board change (rtl/gpu never sees these nets, only the two clocks).
// Reset: async assert from CPU_RESETN (C12, high at rest), sync release after
// three pix_clk edges; the GPU domain gets a second 3-flop pipe in
// pineapple_top.v. The pixel clock is never gated by reset.
module clock_reset(input clk, input cpu_resetn, output pix_clk, output gpu_clk, output reset);
    reg [1:0] div = 0;
    always @(posedge clk) div <= div + 1'b1;
`ifdef PINEAPPLE_SIM
    assign pix_clk = div[1];
    assign gpu_clk = div[0];
`else
    BUFG bufg_pix(.I(div[1]), .O(pix_clk));
    BUFG bufg_gpu(.I(div[0]), .O(gpu_clk));
`endif
    (* ASYNC_REG = "TRUE" *) reg [2:0] reset_pipe = 3'b111;
    always @(posedge pix_clk or negedge cpu_resetn) begin
        if (!cpu_resetn) reset_pipe <= 3'b111;
        else reset_pipe <= {reset_pipe[1:0],1'b0};
    end
    assign reset = reset_pipe[2];
endmodule
