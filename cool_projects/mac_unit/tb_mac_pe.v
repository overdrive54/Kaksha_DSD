`timescale 1ns / 1ps

module tb_multiplier_complete;
    
    // ---------------------------------------------------------
    // DUT signals
    // ---------------------------------------------------------
    reg clk;
    reg rst;
    reg signed [15:0] a;
    reg signed [15:0] b;

    wire signed [31:0] product;
    wire signed [15:0] a_out;
    wire signed [15:0] b_out;

    // ---------------------------------------------------------
    // Instantiate DUT
    // ---------------------------------------------------------
    multiplier_16bit dut (
        .clk     (clk),
        .rst     (rst),
        .a       (a),
        .b       (b),
        .product (product),
        .a_out   (a_out),
        .b_out   (b_out)
    );

    // ---------------------------------------------------------
    // Clock: 10 ns period
    // ---------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // ---------------------------------------------------------
    // Reference model (MAC)
    // ---------------------------------------------------------
    reg signed [31:0] ref_accum;
    reg signed [31:0] ref_next;

    integer errors;
    integer tests;
    integer i;

    // ---------------------------------------------------------
    // Dump waves
    // ---------------------------------------------------------
    initial begin
        $dumpfile("mac_wallace.vcd");
        $dumpvars(0, tb_multiplier_complete);
    end

    // ---------------------------------------------------------
    // Reset
    // ---------------------------------------------------------
    initial begin
        rst    = 1;
        a      = 0;
        b      = 0;
        errors = 0;
        tests  = 0;
        ref_accum = 0;
        ref_next  = 0;

        repeat (2) @(posedge clk);
        rst = 0;
    end

    // ---------------------------------------------------------
    // Stimulus
    // ---------------------------------------------------------
    initial begin
        @(negedge rst);

        // ---------------- Directed tests ----------------
        apply( 16'sd0,     16'sd0     );
        apply( 16'sd1,     16'sd1     );
        apply( 16'sd2,     16'sd3     );
        apply(-16'sd4,     16'sd5     );
        apply(-16'sd7,    -16'sd6     );
        apply( 16'sd32767, 16'sd1     );
        apply(-16'sd32768, 16'sd1     );

        // ---------------- Random tests ------------------
        for (i = 0; i < 300; i = i + 1) begin
            apply($random, $random);
        end

        // Flush pipeline
        repeat (4) @(posedge clk);

        // ---------------- Summary ------------------------
        $display("====================================");
        $display("MAC Wallace Testbench Summary");
        $display("Total tests  : %0d", tests);
        $display("Total errors : %0d", errors);
        if (errors == 0)
            $display("STATUS       : PASS ✅");
        else
            $display("STATUS       : FAIL ❌");
        $display("====================================");

        $finish;
    end

    // ---------------------------------------------------------
    // Apply one test
    // ---------------------------------------------------------
    task apply(
        input signed [15:0] ta,
        input signed [15:0] tb
    );
        begin
            @(posedge clk);
            a <= ta;
            b <= tb;
            ref_next <= ref_accum + (ta * tb);
            tests = tests + 1;
        end
    endtask

    // ---------------------------------------------------------
    // Self-check (1-cycle latency MAC)
    // ---------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            ref_accum <= 0;
        end else begin
            ref_accum <= ref_next;

            if (product !== ref_next) begin
                errors = errors + 1;
                $display(
                    "[ERROR] t=%0t | a=%0d b=%0d | expected=%0d got=%0d",
                    $time, a_out, b_out, ref_next, product
                );
            end
        end
    end

endmodule
