module dmem (
    input  logic        clk,
    input  logic        we,
    /* verilator lint_off UNUSED */
    input  logic [31:0] addr,
    /* verilator lint_on UNUSED */
    input  logic [31:0] wd,
    output logic [31:0] rd
);
    logic [31:0] RAM [255:0];

    assign rd = RAM[addr[9:2]];

    always_ff @(posedge clk) begin
        if (we) begin
            RAM[addr[9:2]] <= wd;
        end
    end
endmodule
