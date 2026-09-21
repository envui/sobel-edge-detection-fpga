`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/05/2026 06:28:54 PM
// Design Name: 
// Module Name: display_mapper_2x
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

module display_mapper_2x #(
    parameter SRC_W  = 320,
    parameter SRC_H  = 240,
    parameter ADDR_W = 17,
    parameter XY_W   = 10
)(
    input  wire [XY_W-1:0] disp_x,
    input  wire [XY_W-1:0] disp_y,
    output wire [ADDR_W-1:0] src_addr
);

    wire [XY_W-1:0] src_x;
    wire [XY_W-1:0] src_y;

    assign src_x    = disp_x >> 1;
    assign src_y    = disp_y >> 1;
    assign src_addr = src_y * SRC_W + src_x;

endmodule