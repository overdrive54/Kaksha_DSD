module id_ex_reg (
    input  logic        clk, reset, clr,

    // Control Inputs
    input  logic        reg_write_id, mem_write_id, mem_read_id, jump_id, branch_id, alu_src_id, jalr_id,
    input  logic [1:0]  result_src_id,
    input  logic [3:0]  alu_control_id,

    // Data Inputs
    input  logic [31:0] rd1_id, rd2_id, pc_id, imm_ext_id, pc_plus4_id,
    input  logic [4:0]  rs1_id, rs2_id, rd_id,
    input  logic [2:0]  funct3_id,

    // Control Outputs
    output logic        reg_write_ex, mem_write_ex, mem_read_ex, jump_ex, branch_ex, alu_src_ex, jalr_ex,
    output logic [1:0]  result_src_ex,
    output logic [3:0]  alu_control_ex,

    // Data Outputs
    output logic [31:0] rd1_ex, rd2_ex, pc_ex, imm_ext_ex, pc_plus4_ex,
    output logic [4:0]  rs1_ex, rs2_ex, rd_ex,
    output logic [2:0]  funct3_ex
);

    always_ff @(posedge clk) begin
        if (reset | clr) begin
            {reg_write_ex, mem_write_ex, mem_read_ex, jump_ex, branch_ex, alu_src_ex, jalr_ex, result_src_ex, alu_control_ex} <= '0;
            {rd1_ex, rd2_ex, pc_ex, imm_ext_ex, pc_plus4_ex, rs1_ex, rs2_ex, rd_ex, funct3_ex} <= '0;
        end else begin
            {reg_write_ex, mem_write_ex, mem_read_ex, jump_ex, branch_ex, alu_src_ex, jalr_ex, result_src_ex, alu_control_ex} <=
            {reg_write_id, mem_write_id, mem_read_id, jump_id, branch_id, alu_src_id, jalr_id, result_src_id, alu_control_id};

            {rd1_ex, rd2_ex, pc_ex, imm_ext_ex, pc_plus4_ex, rs1_ex, rs2_ex, rd_ex, funct3_ex} <=
            {rd1_id, rd2_id, pc_id, imm_ext_id, pc_plus4_id, rs1_id, rs2_id, rd_id, funct3_id};
        end
    end
endmodule
