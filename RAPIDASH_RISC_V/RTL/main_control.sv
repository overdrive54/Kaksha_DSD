module main_control (
    input  logic [6:0] opcode,
    output logic       reg_write, mem_write, mem_read, jump, branch, alu_src,
    output logic [2:0] imm_src,  // FIXED: Expanded to 3 bits
    output logic [1:0] result_src, alu_op
);
    always_comb begin
        case(opcode)
            // Format:  {reg_write, imm_src(3b), alu_src, mem_write, mem_read, result_src, branch, alu_op, jump}
            7'b0110011: {reg_write, imm_src, alu_src, mem_write, mem_read, result_src, branch, alu_op, jump} = 13'b1_000_0_0_0_00_0_10_0; // R-type
            7'b0010011: {reg_write, imm_src, alu_src, mem_write, mem_read, result_src, branch, alu_op, jump} = 13'b1_000_1_0_0_00_0_10_0; // I-type ALU
            7'b0000011: {reg_write, imm_src, alu_src, mem_write, mem_read, result_src, branch, alu_op, jump} = 13'b1_000_1_0_1_01_0_00_0; // lw
            7'b0100011: {reg_write, imm_src, alu_src, mem_write, mem_read, result_src, branch, alu_op, jump} = 13'b0_001_1_1_0_00_0_00_0; // sw
            7'b1100011: {reg_write, imm_src, alu_src, mem_write, mem_read, result_src, branch, alu_op, jump} = 13'b0_010_0_0_0_00_1_01_0; // branch
            7'b1101111: {reg_write, imm_src, alu_src, mem_write, mem_read, result_src, branch, alu_op, jump} = 13'b1_011_0_0_0_10_0_00_1; // jal
            7'b1100111: {reg_write, imm_src, alu_src, mem_write, mem_read, result_src, branch, alu_op, jump} = 13'b1_000_1_0_0_10_0_00_1; // jalr
            default:    {reg_write, imm_src, alu_src, mem_write, mem_read, result_src, branch, alu_op, jump} = 13'b0_000_0_0_0_00_0_00_0;
        endcase
    end
endmodule
