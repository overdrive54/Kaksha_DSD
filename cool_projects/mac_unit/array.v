`timescale 1ns / 1ps

module array #(
    parameter W = 8
)(
    input  wire clk,
    input  wire rst,
    input  wire start,
    input  wire signed [3*W-1:0] a,
    input  wire signed [3*W-1:0] b,
    output wire signed [9*2*W-1:0] result,
    output reg  result_valid
);

    // PE interconnects
    wire signed [W-1:0] a_ij [0:2][0:3];
    wire signed [W-1:0] b_ij [0:3][0:2];
    wire rst_ij [0:2][0:3]; // Interconnects for the pipelined reset beat

    // Skew registers
    reg signed [W-1:0] a_skew [0:2][0:2];
    reg signed [W-1:0] b_skew [0:2][0:2];

    // Control
    reg [4:0] cycle_count;
    reg computing;
    reg [1:0] beats_remaining; 
    
    // Pipelined row-start generation
    reg [1:0] start_delay; 

    integer k, m;

    always @(posedge clk) begin
        if (rst) begin
            for (k = 0; k < 3; k = k + 1) begin
                for (m = 0; m < 3; m = m + 1) begin
                    a_skew[k][m] <= 0;
                    b_skew[k][m] <= 0;
                end
            end

            cycle_count     <= 0;
            computing       <= 0;
            result_valid    <= 0;
            beats_remaining <= 0;
            start_delay     <= 0;
        end else begin
            // Default
            result_valid <= 0;
            
            // Shift the start signal down the rows
            start_delay <= {start_delay[0], start};

            if (start) begin
                computing       <= 1;
                cycle_count     <= 0;
                beats_remaining <= 2; 
            end else if (computing) begin
                cycle_count <= cycle_count + 1;
                
                if (beats_remaining > 0) begin
                    beats_remaining <= beats_remaining - 1;
                end

                if (cycle_count == 8) begin
                    computing    <= 0;
                    result_valid <= 1;
                end
            end

            // Inject + shift data
            if (start || computing) begin
                for (k = 0; k < 3; k = k + 1) begin
                    a_skew[k][0] <= (start || beats_remaining > 0) ? a[k*W +: W] : 0;
                    b_skew[k][0] <= (start || beats_remaining > 0) ? b[k*W +: W] : 0;
                end

                a_skew[1][1] <= a_skew[1][0];
                a_skew[2][1] <= a_skew[2][0];
                a_skew[2][2] <= a_skew[2][1];

                b_skew[1][1] <= b_skew[1][0];
                b_skew[2][1] <= b_skew[2][0];
                b_skew[2][2] <= b_skew[2][1];
            end
        end
    end

    // Boundary connections
    assign a_ij[0][0] = a_skew[0][0];
    assign a_ij[1][0] = a_skew[1][1];
    assign a_ij[2][0] = a_skew[2][2];

    assign b_ij[0][0] = b_skew[0][0];
    assign b_ij[0][1] = b_skew[1][1];
    assign b_ij[0][2] = b_skew[2][2];
    
    // Inject the staggered reset beats into the first column
    assign rst_ij[0][0] = start;
    assign rst_ij[1][0] = start_delay[0];
    assign rst_ij[2][0] = start_delay[1];

    // PE array
    genvar i, j;
    generate
        for (i = 0; i < 3; i = i + 1) begin : row
            for (j = 0; j < 3; j = j + 1) begin : col
                mac_pe_8_bit PE (
                    .clk    (clk),
                    .sys_rst(rst),            // Global init
                    .rst_in (rst_ij[i][j]),   // Pipelined beat in
                    .rst_out(rst_ij[i][j+1]), // Pipelined beat out
                    .a      (a_ij[i][j]),
                    .a_out  (a_ij[i][j+1]),
                    .b      (b_ij[i][j]),
                    .b_out  (b_ij[i+1][j]),
                    .product(result[(i*3 + j)*2*W +: 2*W])
                );
            end
        end
    endgenerate

endmodule
