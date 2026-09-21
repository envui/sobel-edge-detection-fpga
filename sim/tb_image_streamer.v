`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/05/2026 06:49:48 PM
// Design Name: 
// Module Name: tb_image_streamer
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

module tb_image_streamer;

    localparam IMG_W  = 4;
    localparam IMG_H  = 3;
    localparam ADDR_W = 4;
    localparam XY_W   = 4;

    reg clk = 0;
    reg rst = 1;
    reg start = 0;

    wire busy;
    wire pixel_req_valid;
    wire [ADDR_W-1:0] pixel_req_addr;
    wire [XY_W-1:0] pixel_req_x;
    wire [XY_W-1:0] pixel_req_y;
    wire done;

    image_streamer #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ADDR_W(ADDR_W),
        .XY_W(XY_W)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .busy(busy),
        .pixel_req_valid(pixel_req_valid),
        .pixel_req_addr(pixel_req_addr),
        .pixel_req_x(pixel_req_x),
        .pixel_req_y(pixel_req_y),
        .done(done)
    );

    always #5 clk = ~clk;

    integer count;

    initial begin
        count = 0;

        #20;
        rst = 0;
        #10;
        start = 1;
        #10;
        start = 0;

        repeat (20) begin
            @(posedge clk);
            if (pixel_req_valid) begin
                $display("REQ count=%0d addr=%0d x=%0d y=%0d", count, pixel_req_addr, pixel_req_x, pixel_req_y);
                count = count + 1;
            end
        end

        if (count != IMG_W * IMG_H) begin
            $display("FAIL: wrong request count = %0d", count);
            $stop;
        end

        $display("PASS: image_streamer");
        $finish;
    end

endmodule