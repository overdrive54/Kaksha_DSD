module pc_unit (
    input  logic        clk,
    input  logic        reset,
    input  logic        stall,    // From Hazard Unit
    input  logic [31:0] pc_next,  // From Branch/Jump Mux
    output logic [31:0] pc,
    output logic [31:0] pc_plus4
);
    always_ff @(posedge clk) begin
        if (reset) begin
            pc <= 32'd0;
        end else if (!stall) begin
            pc <= pc_next;
        end
    end

    assign pc_plus4 = pc + 32'd4;
endmodule
