`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/05/2026 09:23:21 PM
// Design Name: 
// Module Name: top_hdmi_zybo
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


module top_hdmi_zybo (
    input  wire        proc_clk_in,
    input  wire        rst_btn,
    input  wire [3:0]  sw,
    output wire [3:0]  led,

    output wire        hdmi_tx_clk_p,
    output wire        hdmi_tx_clk_n,
    output wire [2:0]  hdmi_tx_p,
    output wire [2:0]  hdmi_tx_n
);

    wire clk_pix;
    wire clk_serial;
    wire clk_locked;

    clk_wiz_0 u_clk_wiz (
        .clk_in1 (proc_clk_in),
        .reset   (rst_btn),
        .clk_out1(clk_pix),
        .clk_out2(clk_serial),
        .locked  (clk_locked)
    );

    wire rst;
    assign rst = rst_btn | ~clk_locked;

    wire        vid_hsync;
    wire        vid_vsync;
    wire        vid_de;
    wire [7:0]  vid_r;
    wire [7:0]  vid_g;
    wire [7:0]  vid_b;
    wire        vid_pclk;

    sobel_video_core #(
        .IMG_W(320),
        .IMG_H(240),
        .DATA_W(8),
        .ADDR_W(17),
        .XY_W(10),
        .MEM_FILE("image.mem")
    ) u_core (
        .proc_clk_in(proc_clk_in),
        .pix_clk_in (clk_pix),
        .rst_btn    (rst),
        .sw         (sw),
        .led        (led),

        .vid_hsync  (vid_hsync),
        .vid_vsync  (vid_vsync),
        .vid_de     (vid_de),
        .vid_r      (vid_r),
        .vid_g      (vid_g),
        .vid_b      (vid_b),
        .vid_pclk   (vid_pclk)
    );

    wire [23:0] vid_pData;
    assign vid_pData = {vid_r, vid_g, vid_b};

    rgb2dvi_0 u_rgb2dvi (
        .TMDS_Clk_p (hdmi_tx_clk_p),
        .TMDS_Clk_n (hdmi_tx_clk_n),
        .TMDS_Data_p(hdmi_tx_p),
        .TMDS_Data_n(hdmi_tx_n),
        .aRst       (rst),
        .vid_pData  (vid_pData),
        .vid_pVDE   (vid_de),
        .vid_pHSync (vid_hsync),
        .vid_pVSync (vid_vsync),
        .PixelClk   (clk_pix),
        .SerialClk  (clk_serial)
    );

endmodule