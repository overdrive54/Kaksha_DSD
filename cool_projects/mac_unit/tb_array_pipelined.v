`timescale 1ns / 1ps

module tb_array_pipelined();

    // Parameters
    parameter W = 8;

    // Signals
    reg clk;
    reg rst;
    reg start;
    reg signed [3*W-1:0] a;
    reg signed [3*W-1:0] b;
    
    // 2*W = 16 bit outputs, 9 elements total = 144 bits
    wire signed [9*16-1:0] result; 
    wire result_valid;

    // Clock generation (10ns period / 100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // DUT Instantiation
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

    initial begin
        // =========================================================
        // 1. Initial Power-On Reset
        // =========================================================
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
        //
        // Matrix A1:      Matrix B1:      Expected C1 (2 * A1):
        //  1  1  1         2  0  0         2  2  2
        //  1  1  1         0  2  0         2  2  2
        //  1  1  1         0  0  2         2  2  2
        // =========================================================
        $display("Starting Test 1...");
        
        @(negedge clk);
        start = 1;
        // Cycle 1: a = {A20, A10, A00} | b = {B02, B01, B00}
        a = {8'sd1, 8'sd1, 8'sd1}; 
        b = {8'sd0, 8'sd0, 8'sd2};

        @(negedge clk);
        start = 0;
        // Cycle 2: a = {A21, A11, A01} | b = {B12, B11, B10}
        a = {8'sd1, 8'sd1, 8'sd1};
        b = {8'sd0, 8'sd2, 8'sd0};

        @(negedge clk);
        // Cycle 3: a = {A22, A12, A02} | b = {B22, B21, B20}
        a = {8'sd1, 8'sd1, 8'sd1};
        b = {8'sd2, 8'sd0, 8'sd0};

        @(negedge clk);
        a = 0; b = 0; // Pad with zeros

        // Wait for Test 1 to complete
        @(posedge result_valid);
        print_matrix("Result 1 (Expected all 2s)");

        // Wait a few cycles to let the pipeline completely drain
        #50;

        // =========================================================
        // TEST 2: Compute C2 = A2 * B2 (NO GLOBAL RESET)
        // If the pipelined reset fails, these results will be wrong.
        //
        // Matrix A2:      Matrix B2:      Expected C2 (1 * A2):
        //  1  2  3         1  0  0         1  2  3
        //  4  5  6         0  1  0         4  5  6
        //  7  8  9         0  0  1         7  8  9
        // =========================================================
        $display("\nStarting Test 2 (Verifying Pipelined Reset)...");
        
        @(negedge clk);
        start = 1; // <--- This must trigger the pipelined clear wave
        // Cycle 1: a = {A20, A10, A00} | b = {B02, B01, B00}
        a = {8'sd7, 8'sd4, 8'sd1}; 
        b = {8'sd0, 8'sd0, 8'sd1};

        @(negedge clk);
        start = 0;
        // Cycle 2: a = {A21, A11, A01} | b = {B12, B11, B10}
        a = {8'sd8, 8'sd5, 8'sd2};
        b = {8'sd0, 8'sd1, 8'sd0};

        @(negedge clk);
        // Cycle 3: a = {A22, A12, A02} | b = {B22, B21, B20}
        a = {8'sd9, 8'sd6, 8'sd3};
        b = {8'sd1, 8'sd0, 8'sd0};

        @(negedge clk);
        a = 0; b = 0;

        // Wait for Test 2 to complete
        @(posedge result_valid);
        print_matrix("Result 2 (Expected 1 through 9)");
        
        #20 $finish;
    end

    // =========================================================
    // Helper Task to Print the Matrix
    // =========================================================
    task print_matrix;
        input [80*8:1] title; // String input
        begin
            $display("----------------------------------------");
            $display("%s", title);
            $display("----------------------------------------");
            $display("[%4d, %4d, %4d]", 
                $signed(result[0*16 +: 16]), $signed(result[1*16 +: 16]), $signed(result[2*16 +: 16]));
            $display("[%4d, %4d, %4d]", 
                $signed(result[3*16 +: 16]), $signed(result[4*16 +: 16]), $signed(result[5*16 +: 16]));
            $display("[%4d, %4d, %4d]", 
                $signed(result[6*16 +: 16]), $signed(result[7*16 +: 16]), $signed(result[8*16 +: 16]));
            $display("----------------------------------------\n");
        end
    endtask

    // Optional: Dump waveforms
    initial begin
        $dumpfile("systolic_pipeline.vcd");
        $dumpvars(0, tb_array_pipelined);
    end

endmodule
