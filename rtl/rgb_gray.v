`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/05/2026 06:28:54 PM
// Design Name: 
// Module Name: rgb_gray
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

module rgb_gray (
    input  wire [7:0] gray,
    input  wire       de,
    output wire [7:0] r,
    output wire [7:0] g,
    output wire [7:0] b
);

    assign r = de ? gray : 8'h00;
    assign g = de ? gray : 8'h00;
    assign b = de ? gray : 8'h00;

endmodule