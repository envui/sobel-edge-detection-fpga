`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/05/2026 06:49:48 PM
// Design Name: 
// Module Name: tb_top_small
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_top_small;

    localparam IMG_W    = 8;
    localparam IMG_H    = 8;
    localparam ADDR_W   = 6;
    localparam XY_W     = 4;

    reg proc_clk_in = 0;
    reg rst_btn     = 1;
    reg [3:0] sw    = 4'h4;

    wire [3:0] led;
    wire vid_hsync;
    wire vid_vsync;
    wire vid_de;
    wire [7:0] vid_r;
    wire [7:0] vid_g;
    wire [7:0] vid_b;
    wire vid_pclk;

    top_sobel_video_zybo #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .DATA_W(8),
        .ADDR_W(ADDR_W),
        .XY_W(XY_W),
        .MEM_FILE("image_small.mem")
    ) dut (
        .proc_clk_in(proc_clk_in),
        .rst_btn(rst_btn),
        .sw(sw),
        .led(led),
        .vid_hsync(vid_hsync),
        .vid_vsync(vid_vsync),
        .vid_de(vid_de),
        .vid_r(vid_r),
        .vid_g(vid_g),
        .vid_b(vid_b),
        .vid_pclk(vid_pclk)
    );

    always #5 proc_clk_in = ~proc_clk_in;

    initial begin
        #50;
        rst_btn = 0;

        repeat (500) @(posedge proc_clk_in);

        if (led[0] !== 1'b1) begin
            $display("FAIL: frame_done LED did not assert");
            $stop;
        end

        $display("PASS: top_small");
        $finish;
    end

endmodule