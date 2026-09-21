`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/05/2026 06:28:54 PM
// Design Name: 
// Module Name: video_timing_640x480
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

module video_timing_640x480 (
    input  wire        pix_clk,
    input  wire        rst,

    output reg         hsync,
    output reg         vsync,
    output reg         de,
    output reg [10:0]  x,
    output reg [9:0]   y
);

    localparam H_ACTIVE = 640;
    localparam H_FP     = 16;
    localparam H_SYNC   = 96;
    localparam H_BP     = 48;
    localparam H_TOTAL  = 800;

    localparam V_ACTIVE = 480;
    localparam V_FP     = 10;
    localparam V_SYNC   = 2;
    localparam V_BP     = 33;
    localparam V_TOTAL  = 525;

    reg [10:0] hcnt;
    reg [9:0]  vcnt;

    initial begin
        hcnt  = 0;
        vcnt  = 0;
        hsync = 1'b1;
        vsync = 1'b1;
        de    = 1'b0;
        x     = 0;
        y     = 0;
    end

    always @(posedge pix_clk) begin
        if (rst) begin
            hcnt  <= 0;
            vcnt  <= 0;
            hsync <= 1'b1;
            vsync <= 1'b1;
            de    <= 1'b0;
            x     <= 0;
            y     <= 0;
        end else begin
            if (hcnt == H_TOTAL-1) begin
                hcnt <= 0;
                if (vcnt == V_TOTAL-1)
                    vcnt <= 0;
                else
                    vcnt <= vcnt + 1'b1;
            end else begin
                hcnt <= hcnt + 1'b1;
            end

            de <= (hcnt < H_ACTIVE) && (vcnt < V_ACTIVE);

            x <= (hcnt < H_ACTIVE) ? hcnt : 11'd0;
            y <= (vcnt < V_ACTIVE) ? vcnt : 10'd0;

            hsync <= ~((hcnt >= (H_ACTIVE + H_FP)) &&
                       (hcnt <  (H_ACTIVE + H_FP + H_SYNC)));

            vsync <= ~((vcnt >= (V_ACTIVE + V_FP)) &&
                       (vcnt <  (V_ACTIVE + V_FP + V_SYNC)));
        end
    end

endmodule