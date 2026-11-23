module alu_decoder (
    input  logic [1:0] alu_op,    // From Main Control
    input  logic [2:0] funct3,    // instr[14:12]
    input  logic       funct7_5,  // instr[30] - The "modifier" bit
    input  logic       opcode_5,  // instr[5]  - 1 for R-type, 0 for I-type

    output logic [3:0] alu_ctrl
);

    // Determine if we should use the alternate operation (SUB instead of ADD, SRA instead of SRL).
    // For R-type (opcode_5 == 1), funct7_5 applies to both ADD/SUB and shifts.
    // For I-type (opcode_5 == 0), funct7_5 only applies to shifts (funct3 == 101), because
    // for ADDI, bit 30 is just part of the immediate, not a modifier.
    logic use_alt;
    assign use_alt = funct7_5 & (opcode_5 | (funct3 == 3'b101));

    always_comb begin
        case (alu_op)
            2'b00: alu_ctrl = 4'b0000; // Load/Store: Force ADD to calculate address
            2'b01: alu_ctrl = 4'b0001; // Branch: Force SUB for comparison

            2'b10: begin // R-type or I-type ALU operation
                case (funct3)
                    3'b000: alu_ctrl = use_alt ? 4'b0001 : 4'b0000; // SUB or ADD
                    3'b001: alu_ctrl = 4'b0010;                     // SLL
                    3'b010: alu_ctrl = 4'b0011;                     // SLT
                    3'b011: alu_ctrl = 4'b0100;                     // SLTU
                    3'b100: alu_ctrl = 4'b0101;                     // XOR
                    3'b101: alu_ctrl = use_alt ? 4'b0111 : 4'b0110; // SRA or SRL
                    3'b110: alu_ctrl = 4'b1000;                     // OR
                    3'b111: alu_ctrl = 4'b1001;                     // AND
                    default: alu_ctrl = 4'b0000;
                endcase
            end

            default: alu_ctrl = 4'b0000;
        endcase
    end

endmodule
