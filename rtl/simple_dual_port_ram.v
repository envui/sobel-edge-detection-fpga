`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/05/2026 06:28:54 PM
// Design Name: 
// Module Name: simple_dual_port_ram
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

module simple_dual_port_ram #(
    parameter DEPTH  = 76800,
    parameter ADDR_W = 17,
    parameter DATA_W = 8
)(
    input  wire                  wr_clk,
    input  wire                  wr_en,
    input  wire [ADDR_W-1:0]     wr_addr,
    input  wire [DATA_W-1:0]     wr_data,

    input  wire                  rd_clk,
    input  wire [ADDR_W-1:0]     rd_addr,
    output reg  [DATA_W-1:0]     rd_data
);

    reg [DATA_W-1:0] mem [0:DEPTH-1];
    integer i;

    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 0;
    end

    always @(posedge wr_clk) begin
        if (wr_en && (wr_addr < DEPTH))
            mem[wr_addr] <= wr_data;
    end

    always @(posedge rd_clk) begin
        if (rd_addr < DEPTH)
            rd_data <= mem[rd_addr];
        else
            rd_data <= 0;
    end

endmodule