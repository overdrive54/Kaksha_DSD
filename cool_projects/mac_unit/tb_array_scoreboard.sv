`timescale 1ns / 1ps

module tb_array_scoreboard();
    parameter W = 8;

    reg clk;
    reg rst;
    reg start;
    reg signed [3*W-1:0] a, b;
    wire signed [9*16-1:0] result; 
    wire result_valid;

    typedef logic signed [W-1:0] mat8_t [0:2][0:2];
    typedef logic signed [2*W-1:0] mat16_t [0:2][0:2];

    int tests_run = 0;
    int errors = 0;

    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    array #(.W(W)) DUT (
        .clk(clk), .rst(rst), .start(start), 
        .a(a), .b(b), .result(result), .result_valid(result_valid)
    );

    // =========================================================
    // Golden Reference Model
    // =========================================================
    function mat16_t compute_golden(mat8_t A, mat8_t B);
        mat16_t C;
        for(int i=0; i<3; i++) begin
            for(int j=0; j<3; j++) begin
                C[i][j] = 0;
                for(int k=0; k<3; k++) begin
                    C[i][j] += A[i][k] * B[k][j];
                end
            end
        end
        return C;
    endfunction

    // =========================================================
    // Driver & Monitor (Automatic tasks fix memory corruption)
    // =========================================================
    task automatic drive_matrix(mat8_t A, mat8_t B);
        mat16_t expected = compute_golden(A, B);
        int current_test_id = tests_run;

        // Fork a monitor thread that will wake up to capture this specific matrix
        fork
            capture_and_check(current_test_id, expected);
        join_none

        tests_run++;

        @(negedge clk);
        start = 1;
        a = {A[2][0], A[1][0], A[0][0]}; 
        b = {B[0][2], B[0][1], B[0][0]};

        @(negedge clk);
        start = 0;
        a = {A[2][1], A[1][1], A[0][1]}; 
        b = {B[1][2], B[1][1], B[1][0]};

        @(negedge clk);
        a = {A[2][2], A[1][2], A[0][2]}; 
        b = {B[2][2], B[2][1], B[2][0]};

        @(negedge clk); // 1-cycle bubble
        a = 0; b = 0;
    endtask

    task automatic capture_and_check(int test_id, mat16_t golden);
        mat16_t actual;
        
        // Wait 4 cycles from start to capture first diagonal
        repeat(5) @(negedge clk);
        actual[0][0] = result[0*16 +: 16];

        @(negedge clk);
        actual[0][1] = result[1*16 +: 16];
        actual[1][0] = result[3*16 +: 16];

        @(negedge clk);
        actual[0][2] = result[2*16 +: 16];
        actual[1][1] = result[4*16 +: 16];
        actual[2][0] = result[6*16 +: 16];

        @(negedge clk);
        actual[1][2] = result[5*16 +: 16];
        actual[2][1] = result[7*16 +: 16];

        @(negedge clk);
        actual[2][2] = result[8*16 +: 16];

        // Check against scoreboard
        for(int i=0; i<3; i++) begin
            for(int j=0; j<3; j++) begin
                if (actual[i][j] !== golden[i][j]) begin
                    $error("Mismatch in Test %0d at [%0d][%0d]! Expected: %0d, Got: %0d", 
                            test_id, i, j, golden[i][j], actual[i][j]);
                    errors++;
                end
            end
        end
    endtask

    // =========================================================
    // Stimulus Generation
    // =========================================================
    mat8_t rand_A, rand_B;

    initial begin
        // Enable waveform dumping
        $dumpfile("scoreboard.vcd");
        $dumpvars(0, tb_array_scoreboard);

        rst = 1;
        start = 0;
        a = 0; b = 0;
        
        #20;
        @(negedge clk); 
        rst = 0;
        #10;

        $display("Starting rigorous verification...");

        // Corner Case 1: All Zeros
        for(int i=0; i<3; i++) for(int j=0; j<3; j++) begin rand_A[i][j] = 0; rand_B[i][j] = 0; end
        drive_matrix(rand_A, rand_B);

        // Corner Case 2: Maximum Positive (127)
        for(int i=0; i<3; i++) for(int j=0; j<3; j++) begin rand_A[i][j] = 127; rand_B[i][j] = 127; end
        drive_matrix(rand_A, rand_B);

        // Corner Case 3: Maximum Negative (-128)
        for(int i=0; i<3; i++) for(int j=0; j<3; j++) begin rand_A[i][j] = -128; rand_B[i][j] = -128; end
        drive_matrix(rand_A, rand_B);

        // Corner Case 4: Alternating Signs
        for(int i=0; i<3; i++) for(int j=0; j<3; j++) begin rand_A[i][j] = (i+j)%2 ? 127 : -128; rand_B[i][j] = (i+j)%2 ? -128 : 127; end
        drive_matrix(rand_A, rand_B);

        // Randomized Constrained Testing
        for(int t=0; t<50; t++) begin
            for(int i=0; i<3; i++) begin
                for(int j=0; j<3; j++) begin
                    rand_A[i][j] = $urandom_range(255) - 128; // -128 to 127
                    rand_B[i][j] = $urandom_range(255) - 128;
                end
            end
            drive_matrix(rand_A, rand_B);
        end

        // Wait for pipeline to drain
        repeat(15) @(negedge clk);
        
        $display("========================================");
        $display("Scoreboard Results:");
        $display("Tests Run: %0d", tests_run);
        $display("Errors   : %0d", errors);
        $display("========================================");
        if(errors == 0) $display("PASS: Design is functionally correct.");
        else $display("FAIL: Mismatches detected.");
        
        #10 $finish;
    end
endmodule
