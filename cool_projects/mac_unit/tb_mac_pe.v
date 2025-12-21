module tb_mac_pe;

    localparam W = 16;
    localparam ACC_W = 33;

    reg clk = 0;
    reg rst = 1;
    reg clear = 0;
    reg en = 0;
    reg signed [W-1:0] a, b;

    wire signed [W-1:0] a_out, b_out;
    wire signed [ACC_W-1:0] c_out;

    mac_pe dut (
        .clk(clk),
        .rst(rst),
        .clear(clear),
        .en(en),
        .a(a),
        .b(b),
        .a_out(a_out),
        .b_out(b_out),
        .c_out(c_out)
    );

    always #5 clk = ~clk;

    initial begin
        a = 0; b = 0;

        #12 rst = 0;
        en = 1;

        // Simple visible tests
        a = 10;   b = 3;    #10;
        a = -5;   b = 4;    #10;
        a = 7;    b = -6;   #10;
        a = -8;   b = -8;  #10;

        clear = 1;          #10;
        clear = 0;

        a = 9;    b = 9;   #20;

        $finish;
    end

endmodule
