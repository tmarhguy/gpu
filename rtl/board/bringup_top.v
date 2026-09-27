`timescale 1ns/1ps
// M1 board bring-up only. All GPU processing will remain below rtl/gpu/.
module bringup_top(input clk, input cpu_resetn,
    input btnu, btnd, btnl, btnr, btnc,
    output [3:0] dvi_r, dvi_g, dvi_b,
    output dvi_hs, dvi_vs, dvi_de, dvi_clk);
    wire pix_clk, reset;
    clock_reset clocks(.clk(clk), .cpu_resetn(cpu_resetn), .pix_clk(pix_clk), .reset(reset));
    wire [9:0] x, y;
    wire hs, vs, de, vblank_start;
    gpu_scanout timing(.pix_clk(pix_clk), .reset(reset), .x(x), .y(y),
        .hs(hs), .vs(vs), .de(de), .vblank_start(vblank_start));
    wire [7:0] key;
    wire key_ready;
    wire [4:0] buttons;
    // 32768/25 MHz = 1.31 ms; preserve Tomato's debounce/repeat durations.
    keypad #(.SAMPLE(15)) keys(.clk(pix_clk), .reset(reset),
        .btnu(btnu), .btnd(btnd), .btnl(btnl), .btnr(btnr), .btnc(btnc),
        .rd(key_ready), .kb_data(key), .kb_ready(key_ready), .buttons(buttons));
    reg [2:0] mode;
    always @(posedge pix_clk) begin
        if (reset) mode <= 0;
        else if (key_ready) begin
            case (key)
                8'h1e: mode <= 1;
                8'h1f: mode <= 2;
                8'h11: mode <= 3;
                8'h10: mode <= 4;
                8'h0d: mode <= 0;
                default: mode <= mode;
            endcase
        end
    end
    reg [11:0] rgb;
    always @* begin
        rgb = 0;
        if (de) begin
            case (mode)
                1: rgb = 12'hf00;
                2: rgb = 12'h0f0;
                3: rgb = 12'h00f;
                4: rgb = {x[5:2], y[5:2], 4'h8};
                default: begin
                    if (x < 160) rgb = 12'hf00;
                    else if (x < 320) rgb = 12'h0f0;
                    else if (x < 480) rgb = 12'h00f;
                    else rgb = 12'hfff;
                end
            endcase
        end
    end
    dvi_out display(.pix_clk(pix_clk), .r(rgb[11:8]), .g(rgb[7:4]), .b(rgb[3:0]),
        .hs(hs), .vs(vs), .de(de), .dvi_r(dvi_r), .dvi_g(dvi_g), .dvi_b(dvi_b),
        .dvi_hs(dvi_hs), .dvi_vs(dvi_vs), .dvi_de(dvi_de), .dvi_clk(dvi_clk));
endmodule
