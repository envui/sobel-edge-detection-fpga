`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/05/2026 06:49:48 PM
// Design Name: 
// Module Name: tb_sobel_core
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

module tb_sobel_core;

    reg clk = 0;
    reg rst = 1;
    reg window_valid = 0;
    reg [9:0] x_in = 0;
    reg [9:0] y_in = 0;
    reg [7:0] p00, p01, p02;
    reg [7:0] p10, p11, p12;
    reg [7:0] p20, p21, p22;
    reg [7:0] threshold = 8'd50;

    wire edge_valid;
    wire [9:0] x_out;
    wire [9:0] y_out;
    wire [7:0] edge_pixel;

    sobel_core dut (
        .clk(clk),
        .rst(rst),
        .window_valid(window_valid),
        .x_in(x_in),
        .y_in(y_in),
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10), .p11(p11), .p12(p12),
        .p20(p20), .p21(p21), .p22(p22),
        .threshold(threshold),
        .edge_valid(edge_valid),
        .x_out(x_out),
        .y_out(y_out),
        .edge_pixel(edge_pixel)
    );

    always #5 clk = ~clk;

    initial begin
        p00=0; p01=0; p02=0;
        p10=0; p11=0; p12=0;
        p20=0; p21=0; p22=0;

        #20;
        rst = 0;

        @(posedge clk);
        window_valid <= 1;
        p00<=8'd10; p01<=8'd10; p02<=8'd10;
        p10<=8'd10; p11<=8'd10; p12<=8'd10;
        p20<=8'd10; p21<=8'd10; p22<=8'd10;
        x_in<=10'd5; y_in<=10'd6;

        @(posedge clk);
        window_valid <= 0;

        @(posedge clk);
        if (edge_pixel !== 8'h00) begin
            $display("FAIL: flat image should be no edge");
            $stop;
        end

        @(posedge clk);
        window_valid <= 1;
        p00<=8'd0;   p01<=8'd0;   p02<=8'd255;
        p10<=8'd0;   p11<=8'd0;   p12<=8'd255;
        p20<=8'd0;   p21<=8'd0;   p22<=8'd255;
        x_in<=10'd8; y_in<=10'd9;

        @(posedge clk);
        window_valid <= 0;

        @(posedge clk);
        if (edge_pixel !== 8'hFF) begin
            $display("FAIL: vertical edge should trigger");
            $stop;
        end

        $display("PASS: sobel_core");
        $finish;
    end

endmodule