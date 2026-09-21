`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/05/2026 06:28:54 PM
// Design Name: 
// Module Name: image_streamer
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

module image_streamer #(
    parameter IMG_W  = 320,
    parameter IMG_H  = 240,
    parameter ADDR_W = 17,
    parameter XY_W   = 10
)(
    input  wire              clk,
    input  wire              rst,
    input  wire              start,

    output reg               busy,
    output reg               pixel_req_valid,
    output reg  [ADDR_W-1:0] pixel_req_addr,
    output reg  [XY_W-1:0]   pixel_req_x,
    output reg  [XY_W-1:0]   pixel_req_y,
    output reg               done
);

    reg [XY_W-1:0] x;
    reg [XY_W-1:0] y;
    reg running;

    always @(posedge clk) begin
        if (rst) begin
            x               <= 0;
            y               <= 0;
            running         <= 1'b0;
            busy            <= 1'b0;
            pixel_req_valid <= 1'b0;
            pixel_req_addr  <= 0;
            pixel_req_x     <= 0;
            pixel_req_y     <= 0;
            done            <= 1'b0;
        end else begin
            done <= 1'b0;
            pixel_req_valid <= 1'b0;

            if (start && !running) begin
                running <= 1'b1;
                busy    <= 1'b1;
                x       <= 0;
                y       <= 0;
            end else if (running) begin
                pixel_req_valid <= 1'b1;
                pixel_req_addr  <= y * IMG_W + x;
                pixel_req_x     <= x;
                pixel_req_y     <= y;

                if ((x == IMG_W-1) && (y == IMG_H-1)) begin
                    running <= 1'b0;
                    busy    <= 1'b0;
                    done    <= 1'b1;
                    x       <= 0;
                    y       <= 0;
                end else if (x == IMG_W-1) begin
                    x <= 0;
                    y <= y + 1'b1;
                end else begin
                    x <= x + 1'b1;
                end
            end
        end
    end

endmodule