module branch_unit (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic        branch,
    input  logic        jump,
    input  logic [2:0]  funct3,
    output logic        pc_src
);

    logic take_branch;

    always_comb begin
        case (funct3)
            3'b000: take_branch = (a == b);                   // BEQ
            3'b001: take_branch = (a != b);                   // BNE
            3'b100: take_branch = ($signed(a) < $signed(b));  // BLT
            3'b101: take_branch = ($signed(a) >= $signed(b)); // BGE
            3'b110: take_branch = (a < b);                    // BLTU
            3'b111: take_branch = (a >= b);                   // BGEU
            default: take_branch = 1'b0;
        endcase
    end

    // Take the PC branch if it's an unconditional jump, OR a true branch condition
    assign pc_src = jump | (branch & take_branch);

endmodule
