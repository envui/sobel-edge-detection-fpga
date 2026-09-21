`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/05/2026 06:49:48 PM
// Design Name: 
// Module Name: tb_line_buffer_window
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

module tb_line_buffer_window;

    localparam IMG_W  = 4;
    localparam DATA_W = 8;
    localparam XY_W   = 4;

    reg clk = 0;
    reg rst = 1;

    reg pixel_valid_in = 0;
    reg [DATA_W-1:0] pixel_in = 0;
    reg [XY_W-1:0] x_in = 0;
    reg [XY_W-1:0] y_in = 0;

    wire window_valid;
    wire [XY_W-1:0] center_x;
    wire [XY_W-1:0] center_y;

    wire [7:0] p00,p01,p02;
    wire [7:0] p10,p11,p12;
    wire [7:0] p20,p21,p22;

    line_buffer_window #(
        .IMG_W(IMG_W),
        .DATA_W(DATA_W),
        .XY_W(XY_W)
    ) dut (
        .clk(clk),
        .rst(rst),
        .pixel_valid_in(pixel_valid_in),
        .pixel_in(pixel_in),
        .x_in(x_in),
        .y_in(y_in),
        .window_valid(window_valid),
        .center_x(center_x),
        .center_y(center_y),
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10), .p11(p11), .p12(p12),
        .p20(p20), .p21(p21), .p22(p22)
    );

    always #5 clk = ~clk;

    task send_pixel;
        input [7:0] v;
        input [3:0] x;
        input [3:0] y;
        begin
            @(posedge clk);
            pixel_valid_in <= 1'b1;
            pixel_in       <= v;
            x_in           <= x;
            y_in           <= y;
        end
    endtask

    initial begin
        #20;
        rst = 0;

        send_pixel(8'd0,  0,0);
        send_pixel(8'd1,  1,0);
        send_pixel(8'd2,  2,0);
        send_pixel(8'd3,  3,0);

        send_pixel(8'd10, 0,1);
        send_pixel(8'd11, 1,1);
        send_pixel(8'd12, 2,1);
        send_pixel(8'd13, 3,1);

        send_pixel(8'd20, 0,2);
        send_pixel(8'd21, 1,2);
        send_pixel(8'd22, 2,2);
        send_pixel(8'd23, 3,2);

        send_pixel(8'd30, 0,3);
        send_pixel(8'd31, 1,3);
        send_pixel(8'd32, 2,3);
        send_pixel(8'd33, 3,3);

        @(posedge clk);
        pixel_valid_in <= 1'b0;

        repeat (4) begin
            @(posedge clk);
            if (window_valid) begin
                $display("center=(%0d,%0d)", center_x, center_y);
                $display("%0d %0d %0d", p00,p01,p02);
                $display("%0d %0d %0d", p10,p11,p12);
                $display("%0d %0d %0d", p20,p21,p22);
            end
        end

        $display("INFO: inspect printed windows for correctness");
        $finish;
    end

endmodule