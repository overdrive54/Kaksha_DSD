module regfile (
    input  logic        clk,
    input  logic        we,      // Write Enable (from WB stage)
    input  logic [4:0]  rs1,     // Source 1 (from ID stage)
    input  logic [4:0]  rs2,     // Source 2 (from ID stage)
    input  logic [4:0]  rd,      // Destination (from WB stage)
    input  logic [31:0] wd,      // Write Data (from WB stage)
    output logic [31:0] rd1,     // Read Data 1
    output logic [31:0] rd2      // Read Data 2
);

    logic [31:0] registers [31:0];

    // Asynchronous read with internal forwarding for pipelined WB-to-ID bypass
    assign rd1 = (rs1 == 5'd0) ? 32'd0 :
                 ((rs1 == rd) && we) ? wd : registers[rs1];

    assign rd2 = (rs2 == 5'd0) ? 32'd0 :
                 ((rs2 == rd) && we) ? wd : registers[rs2];

    always_ff @(posedge clk) begin
        if (we && rd != 5'd0) begin
            registers[rd] <= wd;
        end
    end

endmodule
