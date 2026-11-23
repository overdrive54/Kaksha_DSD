module if_id_reg (
    input  logic        clk, reset, clr, en,
    input  logic [31:0] pc_if, instr_if, pc_plus4_if,
    output logic [31:0] pc_id, instr_id, pc_plus4_id
);
    always_ff @(posedge clk) begin
        if (reset | clr) begin
            pc_id       <= '0;
            instr_id    <= 32'h00000013; // Canonical RV32I NOP (addi x0, x0, 0)
            pc_plus4_id <= '0;
        end else if (en) begin
            pc_id       <= pc_if;
            instr_id    <= instr_if;
            pc_plus4_id <= pc_plus4_if;
        end
    end
endmodule
