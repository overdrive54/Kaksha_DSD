`timescale 1ns / 1ps

module wallace_tree #(
    parameter W  = 32,
    parameter g = 4
)(
    input  wire [(8*W)-1:0] pp_flat,
    input  wire signed [W-1:0] acc_in,

    output wire [(W)+g-1:0] row0,
    output wire [(W)+g-1:0] row1
);
    localparam WT = (W) + g;  // guard bits for sign + carry
    // -------------------------------------------------
    // Unpack partial products and sign-extend
    // -------------------------------------------------
    wire [WT-1:0] pp [0:7];

    genvar j;
    generate
        for (j = 0; j < 8; j = j + 1) begin
            wire [W-1:0] pp_w;
            assign pp_w = pp_flat[(j+1)*W-1 -: W];

            // sign-extend once
            assign pp[j] = {{(WT-W){pp_w[W-1]}}, pp_w};
        end
    endgenerate

    // Sign-extend accumulator
    wire [WT-1:0] product_ext;
    assign product_ext = {{(WT-W){acc_in[W-1]}}, acc_in};

    // -------------------------------------------------
    // Stage 1: 9 → 6 (three CSAs)
    // -------------------------------------------------
    wire [WT-1:0] s1_0, c1_0;
    wire [WT-1:0] s1_1, c1_1;
    wire [WT-1:0] s1_2, c1_2;

    genvar i;
    generate
        for (i = 0; i < WT; i = i + 1) begin
            fa fa1 (pp[0][i], pp[1][i], pp[2][i], s1_0[i], c1_0[i]);
            fa fa2 (pp[3][i], pp[4][i], pp[5][i], s1_1[i], c1_1[i]);
            fa fa3 (pp[6][i], pp[7][i], product_ext[i], s1_2[i], c1_2[i]);
        end
    endgenerate

    // shift carries
    wire [WT-1:0] c1_0s = {c1_0[WT-2:0], 1'b0};
    wire [WT-1:0] c1_1s = {c1_1[WT-2:0], 1'b0};
    wire [WT-1:0] c1_2s = {c1_2[WT-2:0], 1'b0};

    // -------------------------------------------------
    // Stage 2: 6 → 4
    // -------------------------------------------------
    wire [WT-1:0] c2_0, c2_1,s2_0,s2_1;
    wire [WT-1:0] c2_0s, c2_1s;
    generate
        for (i = 0; i < WT; i = i + 1) begin
            fa fa4 (s1_0[i], c1_0s[i], s1_2[i], s2_0[i], c2_0[i]);
            fa fa5 (s1_1[i], c1_1s[i], c1_2s[i], s2_1[i], c2_1[i]);
        end
    endgenerate

    // shift final carries
    assign c2_0s = {c2_0[WT-2:0], 1'b0};
    assign c2_1s = {c2_1[WT-2:0], 1'b0};
    
    
    wire [WT-1:0] c3_0,s3_0;
    wire [WT-1:0] c3_0s;
    
    generate
        for (i = 0; i < WT; i = i + 1) begin
            fa fa6 (s2_0[i], c2_0s[i], s2_1[i], s3_0[i], c3_0[i]);
        end
    endgenerate
    
    assign c3_0s = {c3_0[WT-2:0], 1'b0};
    
    wire [WT-1:0] c4_0;
    
    generate
        for (i = 0; i < WT; i = i + 1) begin
            fa fa7 (s3_0[i], c3_0s[i], c2_1s[i], row0[i], c4_0[i]);
        end
    endgenerate

    assign row1 = {c4_0[WT-2:0], 1'b0};

endmodule

module multiplier_16bit #(
parameter W=16,
parameter g=4
) (
    input  wire clk,
    input  wire rst,

    input  wire signed [W-1:0] a,
    input  wire signed [W-1:0] b,

    output reg  signed [2*W-1:0] product,
    output reg  signed [W-1:0]   a_out,
    output reg  signed [W-1:0]   b_out
);
    localparam WT = (2*W)+g;
    // ----------------------------------------
    // Accumulator register (explicit, safe)
    // ----------------------------------------
    reg signed [2*W-1:0] acc_reg;

    // ----------------------------------------
    // Booth partial products
    // ----------------------------------------
    wire signed [(8*2*W)-1:0] pp_flat;

    booth_radix4 booth (
        .a(a),
        .b(b),
        .pp_flat(pp_flat)
    );

    // ----------------------------------------
    // Wallace tree: 9 → 2 compression
    // ----------------------------------------
    wire signed [WT-1:0] row0, row1;

    wallace_tree wt (
        .pp_flat(pp_flat),
        .acc_in (acc_reg),
        .row0   (row0),
        .row1   (row1)
    );

    // ----------------------------------------
    // Final carry-propagate adder
    // ----------------------------------------
    wire signed [WT-1:0] final_sum_wide;

    carry_skip_adder cpa (
        .a   (row0),
        .b   (row1),
        .cin (1'b0),
        .sum (final_sum_wide),
        .cout()
    );

    // ----------------------------------------
    // Sequential logic
    // ----------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            product <= 0;
            acc_reg <= 0;
            a_out   <= 0;
            b_out   <= 0;
        end else begin
            // truncate once, at architectural boundary
            product <= final_sum_wide[2*W-1:0];
            acc_reg <= final_sum_wide[2*W-1:0];

            a_out <= a;
            b_out <= b;
        end
    end

endmodule


module cla_4bit (
    input  wire [3:0] a, b,
    input  wire       cin,
    output wire [3:0] sum,
    output wire       cout,
    output wire       prop
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
    parameter W = 16,
    parameter g = 4
)(
    input  wire [(W*2)+g-1:0] a, b,
    input  wire         cin,
    output wire [(W*2)+g-1:0] sum,
    output wire         cout
);
    localparam WT = (2*W)+g;
    localparam BLOCKS = WT / 4;
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
    wire signed [W:0]   a_ext = {a[W-1], a};
    wire        [W+1:0] b_ext = {b[W-1], b, 1'b0};
    
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : BOOTH
            wire [2:0] booth_bits = b_ext[2*i +: 3];
            reg  signed [W+1:0] mult;
            wire signed [2*W-1:0] pp_i;
            
            always @(*) begin
                case (booth_bits)
                    3'b000,
                    3'b111: mult = 0;
                    3'b001,
                    3'b010: mult = {{a_ext[W]}, a_ext};
                    3'b011: mult = {a_ext, 1'b0};
                    3'b100: mult = -{a_ext, 1'b0};
                    3'b101,
                    3'b110: mult = -{{a_ext[W]}, a_ext};
                    default: mult = 0;
                endcase
            end
            
            assign pp_i = $signed(mult) <<< (2*i);
            assign pp_flat[(i+1)*2*W-1 -: 2*W] = pp_i;
        end
    endgenerate
endmodule

module fa (
    input  wire a,
    input  wire b,
    input  wire c,
    output wire sum,
    output wire carry
);
    assign sum   = a ^ b ^ c;
    assign carry = (a & b) | (b & c) | (a & c);
endmodule
