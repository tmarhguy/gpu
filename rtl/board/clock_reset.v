`timescale 1ns/1ps
// 100 MHz oscillator -> 25 MHz BUFG pixel clock, as in Tomato hdmi_test.
// Keep the clock running during reset; asynchronously assert, synchronously release.
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
