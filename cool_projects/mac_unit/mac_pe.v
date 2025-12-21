`timescale 1ns / 1ps

module full_adder (
    input  wire a, b, cin,
    output wire sum, carry
);
    assign sum   = a ^ b ^ cin;
    assign carry = (a & b) | (a & cin) | (b & cin);
endmodule


module cla_4bit (
    input  wire [3:0] a, b,
    input  wire       cin,
    output wire [3:0] sum,
    output wire       cout,
    output wire       prop   // block propagate
);
    wire [3:0] g, p;
    wire [4:0] c;

    assign p = a ^ b;
    assign g = a & b;

    assign c[0] = cin;
    assign c[1] = g[0] | (p[0] & c[0]);
    assign c[2] = g[1] | (p[1] & c[1]);
    assign c[3] = g[2] | (p[2] & c[2]);
    assign c[4] = g[3] | (p[3] & c[3]);

    assign sum  = p ^ c[3:0];
    assign cout = c[4];
    assign prop = &p;
endmodule

module carry_skip_adder #(
    parameter W = 33   // accumulator width
)(
    input  wire [W-1:0] a, b,
    input  wire         cin,
    output wire [W-1:0] sum,
    output wire         cout
);
    localparam BLOCKS = W / 4;

    wire [BLOCKS:0] c;
    wire [BLOCKS-1:0] block_prop;

    assign c[0] = cin;

    genvar i;
    generate
        for (i = 0; i < BLOCKS; i = i + 1) begin : CSA
            wire cout_i;

            cla_4bit cla (
                .a   (a[i*4 +: 4]),
                .b   (b[i*4 +: 4]),
                .cin (c[i]),
                .sum (sum[i*4 +: 4]),
                .cout(cout_i),
                .prop(block_prop[i])
            );

            assign c[i+1] = block_prop[i] ? c[i] : cout_i;
        end
    endgenerate

    assign cout = c[BLOCKS];
endmodule

module booth_radix4 #(
    parameter W = 16
)(
    input  wire signed [W-1:0] a,
    input  wire signed [W-1:0] b,
    output wire signed [(8*2*W)-1:0] pp_flat
);
    wire signed [W:0] a_ext = {a[W-1], a};
    wire        [W:0] b_ext = {b, 1'b0};

    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : BOOTH
            wire [2:0] booth_bits = b_ext[2*i +: 3];
            reg  signed [W:0] mult;
            wire signed [2*W-1:0] pp_i;
            
            always @(*) begin
                case (booth_bits)
                    3'b000, 3'b111: mult = 0;
                    3'b001, 3'b010: mult =  a_ext;
                    3'b011:         mult =  a_ext <<< 1;
                    3'b100:         mult = -(a_ext <<< 1);
                    3'b101, 3'b110: mult = -a_ext;
                    default:        mult = 0;
                endcase
            end

            assign pp_i = mult <<< (2*i);
            assign pp_flat[(i+1)*2*W-1 -: 2*W] = pp_i;
        end
    endgenerate
endmodule

module pp_compressor #(
    parameter W = 33
)(
    input  wire signed [W-1:0] in0, in1, in2, in3, in4,
    output wire signed [W-1:0] sum,
    output wire signed [W-1:0] carry
);
    genvar i;

    assign carry[0] = 1'b0;

    generate
        for (i = 0; i < W-1; i = i + 1) begin : COMP
            wire s1, c1, s2, c2;

            full_adder fa1 (in0[i], in1[i], in2[i], s1, c1);
            full_adder fa2 (s1,     in3[i], in4[i], s2, c2);

            assign sum[i]     = s2;
            assign carry[i+1] = c1 | c2;
        end
    endgenerate

    // MSB sum (no carry out beyond width)
    assign sum[W-1] = in0[W-1] ^ in1[W-1] ^ in2[W-1]
                    ^ in3[W-1] ^ in4[W-1];
endmodule

module mac_pe #(
    parameter W     = 16,
    parameter ACC_W = 33   // extra sign bit
)(
    input  wire                  clk,
    input  wire                  rst,     // synchronous reset
    input  wire                  clear,
    input  wire                  en,
    input  wire signed [W-1:0]   a,
    input  wire signed [W-1:0]   b,

    output reg  signed [W-1:0]   a_out,
    output reg  signed [W-1:0]   b_out,
    output reg  signed [ACC_W-1:0] c_out
);

    /*-----------------------------------------
      Registered inputs
    -----------------------------------------*/
    always @(posedge clk) begin
        if (rst) begin
            a_out <= 0;
            b_out <= 0;
        end else if (en) begin
            a_out <= a;
            b_out <= b;
        end
    end

    /*-----------------------------------------
      Signed multiplication
    -----------------------------------------*/
    wire signed [2*W-1:0] mult;
    assign mult = a_out * b_out;

    /*-----------------------------------------
      Extend product to accumulator width
    -----------------------------------------*/
    wire signed [ACC_W-1:0] mult_ext;
    assign mult_ext = {{(ACC_W-2*W){mult[2*W-1]}}, mult};

    /*-----------------------------------------
      Accumulation (EXPLICIT WIDTH CONTROL)
    -----------------------------------------*/
    wire signed [ACC_W-1:0] acc_sum;
    assign acc_sum = c_out + mult_ext;

    /*-----------------------------------------
      Accumulator register
    -----------------------------------------*/
    always @(posedge clk) begin
        if (rst)
            c_out <= 0;
        else if (clear)
            c_out <= 0;
        else if (en)
            c_out <= acc_sum;
    end

endmodule
