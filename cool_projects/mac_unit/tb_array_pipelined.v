`timescale 1ns / 1ps

module tb_array_pipelined();

    parameter W = 8;

    reg clk;
    reg rst;
    reg start;
    reg signed [3*W-1:0] a;
    reg signed [3*W-1:0] b;
    
    wire signed [9*16-1:0] result; 
    wire result_valid;

    // Arrays to construct the staggered reads
    reg signed [15:0] mat1 [0:2][0:2];
    reg signed [15:0] mat2 [0:2][0:2];

    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    array #(
        .W(W)
    ) DUT (
        .clk(clk),
        .rst(rst),
        .start(start),
        .a(a),
        .b(b),
        .result(result),
        .result_valid(result_valid)
    );

integer i; // Declare variables outside the loop
integer j;

initial begin
    // Clear capture matrices
    for(i = 0; i < 3; i = i + 1) begin
        for(j = 0; j < 3; j = j + 1) begin
            mat1[i][j] = 0;
            mat2[i][j] = 0;
        end
    end
    

        rst = 1;
        start = 0;
        a = 0;
        b = 0;
        
        #20;
        @(negedge clk); 
        rst = 0;
        #10;

        // =========================================================
        // TEST 1: Compute C1 = A1 * B1
        // =========================================================
        $display("Cycle 0: Injecting Test 1...");
        
        @(negedge clk); // Cycle 0
        start = 1;
        a = {8'sd1, 8'sd1, 8'sd1}; 
        b = {8'sd0, 8'sd0, 8'sd2};

        @(negedge clk); // Cycle 1
        start = 0;
        a = {8'sd1, 8'sd1, 8'sd1};
        b = {8'sd0, 8'sd2, 8'sd0};

        @(negedge clk); // Cycle 2
        a = {8'sd1, 8'sd1, 8'sd1};
        b = {8'sd2, 8'sd0, 8'sd0};

        // =========================================================
        // 1-CYCLE BUBBLE
        // Gives PE(0,0) the clock edge to latch its 3rd beat
        // =========================================================
        @(negedge clk); // Cycle 3
        a = 0; b = 0;
        $display("Cycle 3: Bubble (1-cycle gap)");

        // =========================================================
        // TEST 2: Compute C2 = A2 * B2 
        // Simultaneously capturing T1 diagonally before reset hits
        // =========================================================
        @(negedge clk); // Cycle 4
        $display("Cycle 4: Injecting Test 2 & Capturing T1 PE(0,0)...");
        start = 1; 
        a = {8'sd7, 8'sd4, 8'sd1}; 
        b = {8'sd0, 8'sd0, 8'sd1};
        mat1[0][0] = result[0*16 +: 16]; // PE(0,0) T1

        @(negedge clk); // Cycle 5
        start = 0;
        a = {8'sd8, 8'sd5, 8'sd2};
        b = {8'sd0, 8'sd1, 8'sd0};
        mat1[0][1] = result[1*16 +: 16]; // PE(0,1) T1
        mat1[1][0] = result[3*16 +: 16]; // PE(1,0) T1

        @(negedge clk); // Cycle 6
        a = {8'sd9, 8'sd6, 8'sd3};
        b = {8'sd1, 8'sd0, 8'sd0};
        mat1[0][2] = result[2*16 +: 16]; // PE(0,2) T1
        mat1[1][1] = result[4*16 +: 16]; // PE(1,1) T1
        mat1[2][0] = result[6*16 +: 16]; // PE(2,0) T1

        @(negedge clk); // Cycle 7
        a = 0; b = 0; 
        mat1[1][2] = result[5*16 +: 16]; // PE(1,2) T1
        mat1[2][1] = result[7*16 +: 16]; // PE(2,1) T1

        @(negedge clk); // Cycle 8
        mat1[2][2] = result[8*16 +: 16]; // PE(2,2) T1
        mat2[0][0] = result[0*16 +: 16]; // PE(0,0) T2

        @(negedge clk); // Cycle 9
        mat2[0][1] = result[1*16 +: 16]; // PE(0,1) T2
        mat2[1][0] = result[3*16 +: 16]; // PE(1,0) T2

        @(negedge clk); // Cycle 10
        mat2[0][2] = result[2*16 +: 16]; // PE(0,2) T2
        mat2[1][1] = result[4*16 +: 16]; // PE(1,1) T2
        mat2[2][0] = result[6*16 +: 16]; // PE(2,0) T2

        @(negedge clk); // Cycle 11
        mat2[1][2] = result[5*16 +: 16]; // PE(1,2) T2
        mat2[2][1] = result[7*16 +: 16]; // PE(2,1) T2

        @(negedge clk); // Cycle 12
        mat2[2][2] = result[8*16 +: 16]; // PE(2,2) T2

        // =========================================================
        // Print Results
        // =========================================================
        $display("----------------------------------------");
        $display("Result 1 (Expected all 2s)");
        $display("----------------------------------------");
        $display("[%4d, %4d, %4d]", mat1[0][0], mat1[0][1], mat1[0][2]);
        $display("[%4d, %4d, %4d]", mat1[1][0], mat1[1][1], mat1[1][2]);
        $display("[%4d, %4d, %4d]", mat1[2][0], mat1[2][1], mat1[2][2]);
        $display("----------------------------------------\n");

        $display("----------------------------------------");
        $display("Result 2 (Expected 1 through 9)");
        $display("----------------------------------------");
        $display("[%4d, %4d, %4d]", mat2[0][0], mat2[0][1], mat2[0][2]);
        $display("[%4d, %4d, %4d]", mat2[1][0], mat2[1][1], mat2[1][2]);
        $display("[%4d, %4d, %4d]", mat2[2][0], mat2[2][1], mat2[2][2]);
        $display("----------------------------------------\n");

        #20 $finish;
    end
endmodule
