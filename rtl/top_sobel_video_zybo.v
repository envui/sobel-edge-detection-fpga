`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/05/2026 06:28:54 PM
// Design Name: 
// Module Name: top_sobel_video_zybo
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

module top_sobel_video_zybo #(
    parameter IMG_W     = 320,
    parameter IMG_H     = 240,
    parameter DATA_W    = 8,
    parameter ADDR_W    = 17,
    parameter XY_W      = 10,
    parameter MEM_FILE  = "image.mem"
)(
    input  wire             proc_clk_in,
    input  wire             rst_btn,
    input  wire [3:0]       sw,
    output wire [3:0]       led

    //output wire             vid_hsync,
    //output wire             vid_vsync,
    //output wire             vid_de,
    //output wire [7:0]       vid_r,
    //output wire [7:0]       vid_g,
    //output wire [7:0]       vid_b,
    //output wire             vid_pclk
);


    localparam DEPTH = IMG_W * IMG_H;
    
    wire             vid_hsync;
    wire             vid_vsync;
    wire             vid_de;
    wire [7:0]       vid_r;
    wire [7:0]       vid_g;
    wire [7:0]       vid_b;
    wire             vid_pclk;
    
    wire rst;
    assign rst = rst_btn;

    wire [7:0] threshold;
    assign threshold = {sw, sw};

    // Temporary divided pixel clock for core/video testing.
    // Replace with Clocking Wizard output when doing final HDMI hookup.
    wire pix_clk;
    clock_div_5 u_clkdiv (
        .clk_in(proc_clk_in),
        .rst(rst),
        .clk_out(pix_clk)
    );

    assign vid_pclk = pix_clk;

    wire               str_busy;
    wire               str_valid;
    wire [ADDR_W-1:0]  str_addr;
    wire [XY_W-1:0]    str_x;
    wire [XY_W-1:0]    str_y;
    wire               str_done;

    reg start_stream;

    image_streamer #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ADDR_W(ADDR_W),
        .XY_W(XY_W)
    ) u_streamer (
        .clk(proc_clk_in),
        .rst(rst),
        .start(start_stream),
        .busy(str_busy),
        .pixel_req_valid(str_valid),
        .pixel_req_addr(str_addr),
        .pixel_req_x(str_x),
        .pixel_req_y(str_y),
        .done(str_done)
    );

    always @(posedge proc_clk_in) begin
        if (rst)
            start_stream <= 1'b1;
        else
            start_stream <= 1'b0;
    end

    wire [DATA_W-1:0] rom_pixel;

    image_rom #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .DATA_W(DATA_W),
        .ADDR_W(ADDR_W),
        .MEM_FILE(MEM_FILE)
    ) u_rom (
        .clk(proc_clk_in),
        .addr(str_addr),
        .dout(rom_pixel)
    );

    reg             pix_valid_d;
    reg [XY_W-1:0]  x_d;
    reg [XY_W-1:0]  y_d;

    always @(posedge proc_clk_in) begin
        if (rst) begin
            pix_valid_d <= 1'b0;
            x_d         <= 0;
            y_d         <= 0;
        end else begin
            pix_valid_d <= str_valid;
            x_d         <= str_x;
            y_d         <= str_y;
        end
    end

    wire            win_valid;
    wire [XY_W-1:0] win_x;
    wire [XY_W-1:0] win_y;

    wire [7:0] p00, p01, p02;
    wire [7:0] p10, p11, p12;
    wire [7:0] p20, p21, p22;

    line_buffer_window #(
        .IMG_W(IMG_W),
        .DATA_W(DATA_W),
        .XY_W(XY_W)
    ) u_window (
        .clk(proc_clk_in),
        .rst(rst),
        .pixel_valid_in(pix_valid_d),
        .pixel_in(rom_pixel),
        .x_in(x_d),
        .y_in(y_d),
        .window_valid(win_valid),
        .center_x(win_x),
        .center_y(win_y),
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10), .p11(p11), .p12(p12),
        .p20(p20), .p21(p21), .p22(p22)
    );

    wire            edge_valid;
    wire [XY_W-1:0] edge_x;
    wire [XY_W-1:0] edge_y;
    wire [7:0]      edge_pixel;

    sobel_core #(
        .DATA_W(DATA_W),
        .XY_W(XY_W)
    ) u_sobel (
        .clk(proc_clk_in),
        .rst(rst),
        .window_valid(win_valid),
        .x_in(win_x),
        .y_in(win_y),
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10), .p11(p11), .p12(p12),
        .p20(p20), .p21(p21), .p22(p22),
        .threshold(threshold),
        .edge_valid(edge_valid),
        .x_out(edge_x),
        .y_out(edge_y),
        .edge_pixel(edge_pixel)
    );

    wire [ADDR_W-1:0] fb_wr_addr;
    assign fb_wr_addr = edge_y * IMG_W + edge_x;

    wire [10:0] disp_x;
    wire [9:0]  disp_y;

    video_timing_640x480 u_timing (
        .pix_clk(pix_clk),
        .rst(rst),
        .hsync(vid_hsync),
        .vsync(vid_vsync),
        .de(vid_de),
        .x(disp_x),
        .y(disp_y)
    );

    wire [ADDR_W-1:0] fb_rd_addr;
    display_mapper_2x #(
        .SRC_W(IMG_W),
        .SRC_H(IMG_H),
        .ADDR_W(ADDR_W),
        .XY_W(XY_W)
    ) u_mapper (
        .disp_x(disp_x[XY_W-1:0]),
        .disp_y(disp_y[XY_W-1:0]),
        .src_addr(fb_rd_addr)
    );

    wire [7:0] fb_rd_data;

    simple_dual_port_ram #(
        .DEPTH(DEPTH),
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W)
    ) u_fb (
        .wr_clk(proc_clk_in),
        .wr_en(edge_valid),
        .wr_addr(fb_wr_addr),
        .wr_data(edge_pixel),
        .rd_clk(pix_clk),
        .rd_addr(fb_rd_addr),
        .rd_data(fb_rd_data)
    );

    rgb_gray u_rgb (
        .gray(fb_rd_data),
        .de(vid_de),
        .r(vid_r),
        .g(vid_g),
        .b(vid_b)
    );

    reg frame_done;
    reg [3:0] done_pipe;

    always @(posedge proc_clk_in) begin
        if (rst) begin
            done_pipe  <= 4'b0000;
            frame_done <= 1'b0;
        end else begin
            done_pipe <= {done_pipe[2:0], str_done};
            if (done_pipe[3])
                frame_done <= 1'b1;
        end
    end

    assign led[0] = frame_done;
    assign led[1] = str_busy;
    assign led[2] = edge_valid;
    assign led[3] = vid_de;

endmodule