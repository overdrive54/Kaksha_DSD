module mem_wb_reg (
    input  logic        clk, reset,

    // Control Signals IN
    input  logic        reg_write_mem,
    input  logic [1:0]  result_src_mem,

    // Data IN
    input  logic [31:0] alu_result_mem,
    input  logic [31:0] read_data_mem,
    input  logic [31:0] pc_plus4_mem,
    input  logic [4:0]  rd_mem,

    // Control Signals OUT
    output logic        reg_write_wb,
    output logic [1:0]  result_src_wb,

    // Data OUT
    output logic [31:0] alu_result_wb,
    output logic [31:0] read_data_wb,
    output logic [31:0] pc_plus4_wb,
    output logic [4:0]  rd_wb
);

    always_ff @(posedge clk) begin
        if (reset) begin
            {reg_write_wb, result_src_wb} <= '0;
            {alu_result_wb, read_data_wb, pc_plus4_wb, rd_wb} <= '0;
        end else begin
            reg_write_wb  <= reg_write_mem;
            result_src_wb <= result_src_mem;

            alu_result_wb <= alu_result_mem;
            read_data_wb  <= read_data_mem;
            pc_plus4_wb   <= pc_plus4_mem;
            rd_wb         <= rd_mem;
        end
    end

endmodule
