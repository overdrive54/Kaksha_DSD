module imem (
    /* verilator lint_off UNUSED */
    input  logic [31:0] addr,
    /* verilator lint_on UNUSED */
    output logic [31:0] instr
);
    logic [31:0] RAM [255:0];

    initial begin
        $readmemh("firmware.hex", RAM);
    end

    assign instr = RAM[addr[9:2]];
endmodule
