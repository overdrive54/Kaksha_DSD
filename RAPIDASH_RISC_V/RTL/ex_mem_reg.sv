module ex_mem_reg (
    input  logic        clk,
    input  logic        rst_or_flush,

    // Control Signals IN (from EX)
    input  logic        reg_write_ex,
    input  logic [1:0]  result_src_ex,
    input  logic        mem_write_ex,
    input  logic        mem_read_ex,

    // Data IN (from EX)
    input  logic [31:0] alu_result_ex,
    input  logic [31:0] write_data_ex,
    input  logic [31:0] pc_plus4_ex, // Carried over for JAL/JALR
    input  logic [4:0]  rd_ex,

    // Control Signals OUT (to MEM)
    output logic        reg_write_mem,
    output logic [1:0]  result_src_mem,
    output logic        mem_write_mem,
    output logic        mem_read_mem,

    // Data OUT (to MEM)
    output logic [31:0] alu_result_mem,
    output logic [31:0] write_data_mem,
    output logic [31:0] pc_plus4_mem,
    output logic [4:0]  rd_mem
);

    always_ff @(posedge clk) begin
        if (rst_or_flush) begin
            reg_write_mem  <= 1'b0;
            mem_write_mem  <= 1'b0;
            mem_read_mem   <= 1'b0;
            result_src_mem <= 2'b00;
            alu_result_mem <= 32'd0;
            write_data_mem <= 32'd0;
            pc_plus4_mem   <= 32'd0;
            rd_mem         <= 5'd0;
        end else begin
            // Control path
            reg_write_mem  <= reg_write_ex;
            result_src_mem <= result_src_ex;
            mem_write_mem  <= mem_write_ex;
            mem_read_mem   <= mem_read_ex;

            // Data path
            alu_result_mem <= alu_result_ex;
            write_data_mem <= write_data_ex;
            pc_plus4_mem   <= pc_plus4_ex;
            rd_mem         <= rd_ex;
        end
    end

endmodule
