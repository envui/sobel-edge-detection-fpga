`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/05/2026 06:28:54 PM
// Design Name: 
// Module Name: clock_div_5
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

module clock_div_5 (
    input  wire clk_in,
    input  wire rst,
    output reg  clk_out
);

    reg [2:0] cnt;

    initial begin
        cnt     = 3'd0;
        clk_out = 1'b0;
    end

    always @(posedge clk_in) begin
        if (rst) begin
            cnt     <= 3'd0;
            clk_out <= 1'b0;
        end else begin
            if (cnt == 3'd4) begin
                cnt     <= 3'd0;
                clk_out <= ~clk_out;
            end else begin
                cnt <= cnt + 1'b1;
            end
        end
    end

endmodule