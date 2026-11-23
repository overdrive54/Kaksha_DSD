module hazard_detection_unit (
    input  logic [4:0] rs1_addr_id,  // Source 1 from Decode stage
    input  logic [4:0] rs2_addr_id,  // Source 2 from Decode stage
    input  logic [4:0] rd_addr_ex,   // Destination from Execute stage
    input  logic       mem_read_ex,  // Load instruction flag in Execute stage

    output logic       stall         // Stall signal to PC and Pipeline registers
);

    always_comb begin
        // Check if the instruction in EX is a LOAD and its destination matches
        // either of the sources for the current instruction in ID.
        if (mem_read_ex && (rd_addr_ex != 5'd0) &&
           ((rd_addr_ex == rs1_addr_id) || (rd_addr_ex == rs2_addr_id))) begin
            stall = 1'b1;
        end else begin
            stall = 1'b0;
        end
    end

endmodule
