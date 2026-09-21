`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/05/2026 06:28:54 PM
// Design Name: 
// Module Name: sobel_core
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


module sobel_core #(
    parameter DATA_W = 8,
    parameter XY_W   = 10
)(
    input  wire                  clk,
    input  wire                  rst,

    input  wire                  window_valid,
    input  wire [XY_W-1:0]       x_in,
    input  wire [XY_W-1:0]       y_in,

    input  wire [DATA_W-1:0]     p00, p01, p02,
    input  wire [DATA_W-1:0]     p10, p11, p12,
    input  wire [DATA_W-1:0]     p20, p21, p22,

    input  wire [7:0]            threshold,

    output reg                   edge_valid,
    output reg [XY_W-1:0]        x_out,
    output reg [XY_W-1:0]        y_out,
    output reg [7:0]             edge_pixel
);

    reg signed [11:0] gx_calc;
    reg signed [11:0] gy_calc;
    reg [12:0] mag_calc;

    always @(posedge clk) begin
        if (rst) begin
            gx_calc     <= 0;
            gy_calc     <= 0;
            mag_calc    <= 0;
            edge_valid  <= 1'b0;
            x_out       <= 0;
            y_out       <= 0;
            edge_pixel  <= 0;
        end else begin
            edge_valid <= 1'b0;

            if (window_valid) begin
                gx_calc = -$signed({4'b0,p00}) + $signed({4'b0,p02})
                        - ($signed({4'b0,p10}) <<< 1) + ($signed({4'b0,p12}) <<< 1)
                        - $signed({4'b0,p20}) + $signed({4'b0,p22});

                gy_calc = -$signed({4'b0,p00}) - ($signed({4'b0,p01}) <<< 1) - $signed({4'b0,p02})
                        +  $signed({4'b0,p20}) + ($signed({4'b0,p21}) <<< 1) + $signed({4'b0,p22});

                mag_calc = ((gx_calc < 0) ? -gx_calc : gx_calc) +
                           ((gy_calc < 0) ? -gy_calc : gy_calc);

                x_out      <= x_in;
                y_out      <= y_in;
                edge_pixel <= (mag_calc > threshold) ? 8'hFF : 8'h00;
                edge_valid <= 1'b1;
            end
        end
    end

endmodule