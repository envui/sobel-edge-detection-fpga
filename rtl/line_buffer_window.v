`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/05/2026 06:28:54 PM
// Design Name: 
// Module Name: line_buffer_window
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

module line_buffer_window #(
    parameter IMG_W  = 320,
    parameter DATA_W = 8,
    parameter XY_W   = 10
)(
    input  wire                clk,
    input  wire                rst,

    input  wire                pixel_valid_in,
    input  wire [DATA_W-1:0]   pixel_in,
    input  wire [XY_W-1:0]     x_in,
    input  wire [XY_W-1:0]     y_in,

    output reg                 window_valid,
    output reg [XY_W-1:0]      center_x,
    output reg [XY_W-1:0]      center_y,

    output reg [DATA_W-1:0]    p00, p01, p02,
    output reg [DATA_W-1:0]    p10, p11, p12,
    output reg [DATA_W-1:0]    p20, p21, p22
);

    reg [DATA_W-1:0] line1 [0:IMG_W-1];
    reg [DATA_W-1:0] line2 [0:IMG_W-1];

    reg [DATA_W-1:0] cur0,  cur1,  cur2;
    reg [DATA_W-1:0] prv0,  prv1,  prv2;
    reg [DATA_W-1:0] prv20, prv21, prv22;

    reg [DATA_W-1:0] s_line1;
    reg [DATA_W-1:0] s_line2;

    integer i;

    initial begin
        for (i = 0; i < IMG_W; i = i + 1) begin
            line1[i] = 0;
            line2[i] = 0;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            window_valid <= 1'b0;
            center_x     <= 0;
            center_y     <= 0;

            cur0 <= 0; cur1 <= 0; cur2 <= 0;
            prv0 <= 0; prv1 <= 0; prv2 <= 0;
            prv20 <= 0; prv21 <= 0; prv22 <= 0;

            p00 <= 0; p01 <= 0; p02 <= 0;
            p10 <= 0; p11 <= 0; p12 <= 0;
            p20 <= 0; p21 <= 0; p22 <= 0;
        end else begin
            window_valid <= 1'b0;

            if (pixel_valid_in) begin
                s_line1 = line1[x_in];
                s_line2 = line2[x_in];

                line2[x_in] <= line1[x_in];
                line1[x_in] <= pixel_in;

                prv20 <= prv21;
                prv21 <= prv22;
                prv22 <= s_line2;

                prv0  <= prv1;
                prv1  <= prv2;
                prv2  <= s_line1;

                cur0  <= cur1;
                cur1  <= cur2;
                cur2  <= pixel_in;

                p00 <= prv20;
                p01 <= prv21;
                p02 <= prv22;

                p10 <= prv0;
                p11 <= prv1;
                p12 <= prv2;

                p20 <= cur0;
                p21 <= cur1;
                p22 <= cur2;

                if ((x_in >= 2) && (y_in >= 2)) begin
                    window_valid <= 1'b1;
                    center_x     <= x_in - 1;
                    center_y     <= y_in - 1;
                end
            end
        end
    end

endmodule