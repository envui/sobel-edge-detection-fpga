`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/05/2026 06:28:54 PM
// Design Name: 
// Module Name: image_rom
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

module image_rom #(
    parameter IMG_W = 320,
    parameter IMG_H = 240,
    parameter DATA_W = 8,
    parameter ADDR_W = 17,
    parameter MEM_FILE = "image.mem"
)(
    input  wire                  clk,
    input  wire [ADDR_W-1:0]     addr,
    output reg  [DATA_W-1:0]     dout
);

    localparam DEPTH = IMG_W * IMG_H;

    reg [DATA_W-1:0] mem [0:DEPTH-1];
    integer i;

    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = {DATA_W{1'b0}};
        $readmemh(MEM_FILE, mem);
    end

    always @(posedge clk) begin
        if (addr < DEPTH)
            dout <= mem[addr];
        else
            dout <= {DATA_W{1'b0}};
    end

endmodule