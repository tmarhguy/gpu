`timescale 1ns/1ps
// Timing only: board-level pixel stream boundary. Framebuffer fetch arrives in M2.
module gpu_scanout(input pix_clk, input reset,
    output reg [9:0] x, output reg [9:0] y,
    output hs, output vs, output de, output vblank_start);
    always @(posedge pix_clk) begin
        if (reset) begin x <= 0; y <= 0; end
        else if (x == 799) begin
            x <= 0;
            y <= (y == 524) ? 10'd0 : y + 1'b1;
        end else x <= x + 1'b1;
    end
    assign de = !reset && x < 640 && y < 480;
    assign hs = !((x >= 656) && (x < 752));
    assign vs = !((y >= 490) && (y < 492));
    assign vblank_start = !reset && x == 0 && y == 480;
endmodule
