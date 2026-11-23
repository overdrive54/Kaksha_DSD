module top (
    input  logic        clk,
    input  logic        reset,

    // Testbench observability ports
    output logic        test_we,
    output logic [31:0] test_addr,
    output logic [31:0] test_data
);

    // =========================================================================
    // PIPELINE SIGNAL DECLARATIONS
    // =========================================================================

    // Hazard & Flush Signals
    logic stall;
    logic flush_id, flush_ex;

    // IF Signals
    logic [31:0] pc_next, pc_if, pc_plus4_if, instr_if;

    // ID Signals
    logic [31:0] pc_id, instr_id, pc_plus4_id, rd1_id, rd2_id, imm_ext_id;
    logic [3:0]  alu_ctrl_id;
    logic [2:0]  imm_src_id;
    logic [1:0]  result_src_id, alu_op_id;
    logic        reg_write_id, mem_write_id, mem_read_id, branch_id, jump_id, alu_src_id, jalr_id;

    // EX Signals
    logic [31:0] pc_ex, pc_plus4_ex, rd1_ex, rd2_ex, imm_ext_ex;
    logic [31:0] src_a_ex, src_b_ex, forward_b_val, alu_result_ex, pc_target_ex;
    logic [4:0]  rs1_ex, rs2_ex, rd_ex;
    logic [3:0]  alu_ctrl_ex;
    logic [2:0]  funct3_ex;
    logic [1:0]  result_src_ex, forward_a, forward_b;
    logic        reg_write_ex, mem_write_ex, mem_read_ex, branch_ex, jump_ex, alu_src_ex, jalr_ex;
    logic        pc_src_ex;

    // MEM Signals
    logic [31:0] alu_result_mem, write_data_mem, read_data_mem, pc_plus4_mem;
    logic [4:0]  rd_mem;
    logic [1:0]  result_src_mem;
    logic        reg_write_mem, mem_write_mem, mem_read_mem; //

    // WB Signals
    logic [31:0] alu_result_wb, read_data_wb, pc_plus4_wb, result_wb;
    logic [4:0]  rd_wb;
    logic [1:0]  result_src_wb;
    logic        reg_write_wb;


    // =========================================================================
    // INSTRUCTION FETCH (IF) STAGE
    // =========================================================================

    assign pc_next = pc_src_ex ? pc_target_ex : pc_plus4_if;

    pc_unit pc_inst (
        .clk        (clk),
        .reset      (reset),
        .stall      (stall),
        .pc_next    (pc_next),
        .pc         (pc_if),
        .pc_plus4   (pc_plus4_if)
    );

    imem imem_inst (
        .addr       (pc_if),
        .instr      (instr_if)
    );

    // Flush ID on taken branch
    assign flush_id = pc_src_ex;

    if_id_reg if_id_inst (
        .clk        (clk),
        .reset      (reset),
        .clr        (flush_id),
        .en         (~stall),
        .pc_if      (pc_if),
        .instr_if   (instr_if),
        .pc_plus4_if(pc_plus4_if),
        .pc_id      (pc_id),
        .instr_id   (instr_id),
        .pc_plus4_id(pc_plus4_id)
    );


    // =========================================================================
    // INSTRUCTION DECODE (ID) STAGE
    // =========================================================================

    main_control ctrl_inst (
        .opcode     (instr_id[6:0]),
        .reg_write  (reg_write_id),
        .mem_write  (mem_write_id),
        .mem_read   (mem_read_id),
        .branch     (branch_id),
        .jump       (jump_id),
        .alu_src    (alu_src_id),
        .result_src (result_src_id),
        .imm_src    (imm_src_id),
        .alu_op     (alu_op_id)
    );

    regfile rf_inst (
        .clk        (clk),
        .we         (reg_write_wb),
        .rs1        (instr_id[19:15]),
        .rs2        (instr_id[24:20]),
        .rd         (rd_wb),
        .wd         (result_wb),
        .rd1        (rd1_id),
        .rd2        (rd2_id)
    );

    sign_extend se_inst (
        .instr      (instr_id[31:7]),
        .imm_src    (imm_src_id),
        .imm_ext    (imm_ext_id)
    );

    alu_decoder aludec_inst (
        .alu_op     (alu_op_id),
        .funct3     (instr_id[14:12]),
        .funct7_5   (instr_id[30]),
        .opcode_5   (instr_id[5]),
        .alu_ctrl   (alu_ctrl_id)
    );

    hazard_detection_unit hazard_inst (
        .rs1_addr_id(instr_id[19:15]),
        .rs2_addr_id(instr_id[24:20]),
        .rd_addr_ex (rd_ex),
        .mem_read_ex(mem_read_ex),
        .stall      (stall)
    );

    assign jalr_id = (instr_id[6:0] == 7'b1100111);

    // Flush EX on taken branch OR a load-use stall (creates bubble)
    assign flush_ex = pc_src_ex | stall;

    id_ex_reg id_ex_inst (
        .clk            (clk),
        .reset          (reset),
        .clr            (flush_ex),
        // Control IN
        .reg_write_id   (reg_write_id),
        .result_src_id  (result_src_id),
        .mem_write_id   (mem_write_id),
        .mem_read_id    (mem_read_id),
        .jump_id        (jump_id),
        .branch_id      (branch_id),
        .alu_control_id (alu_ctrl_id),
        .alu_src_id     (alu_src_id),
        .jalr_id        (jalr_id),
        // Data IN
        .rd1_id         (rd1_id),
        .rd2_id         (rd2_id),
        .pc_id          (pc_id),
        .imm_ext_id     (imm_ext_id),
        .pc_plus4_id    (pc_plus4_id),
        .rs1_id         (instr_id[19:15]),
        .rs2_id         (instr_id[24:20]),
        .rd_id          (instr_id[11:7]),
        .funct3_id      (instr_id[14:12]),
        // Control OUT
        .reg_write_ex   (reg_write_ex),
        .result_src_ex  (result_src_ex),
        .mem_write_ex   (mem_write_ex),
        .mem_read_ex    (mem_read_ex),
        .jump_ex        (jump_ex),
        .branch_ex      (branch_ex),
        .alu_control_ex (alu_ctrl_ex),
        .alu_src_ex     (alu_src_ex),
        .jalr_ex        (jalr_ex),
        // Data OUT
        .rd1_ex         (rd1_ex),
        .rd2_ex         (rd2_ex),
        .pc_ex          (pc_ex),
        .imm_ext_ex     (imm_ext_ex),
        .pc_plus4_ex    (pc_plus4_ex),
        .rs1_ex         (rs1_ex),
        .rs2_ex         (rs2_ex),
        .rd_ex          (rd_ex),
        .funct3_ex      (funct3_ex)
    );


    // =========================================================================
    // EXECUTE (EX) STAGE
    // =========================================================================

    // Branch Target Calculation
    assign pc_target_ex = jalr_ex ? alu_result_ex : (pc_ex + imm_ext_ex);

    forwarding_unit fwd_inst (
        .rs1_addr_ex    (rs1_ex),
        .rs2_addr_ex    (rs2_ex),
        .rd_addr_mem    (rd_mem),
        .reg_write_mem  (reg_write_mem),
        .rd_addr_wb     (rd_wb),
        .reg_write_wb   (reg_write_wb),
        .forward_a      (forward_a),
        .forward_b      (forward_b)
    );

    // Forwarding Multiplexers
    assign src_a_ex      = (forward_a == 2'b10) ? alu_result_mem :
                           (forward_a == 2'b01) ? result_wb      : rd1_ex;

    assign forward_b_val = (forward_b == 2'b10) ? alu_result_mem :
                           (forward_b == 2'b01) ? result_wb      : rd2_ex;

    assign src_b_ex      = alu_src_ex ? imm_ext_ex : forward_b_val;

    logic unused_zero; // Declare near your EX signals

    alu alu_inst (
        .a              (src_a_ex),
        .b              (src_b_ex),
        .alu_ctrl       (alu_ctrl_ex),
        .result         (alu_result_ex),
        .zero           (unused_zero) // Connected to dummy wire
    );

    branch_unit branch_inst (
        .a              (src_a_ex),
        .b              (src_b_ex),
        .branch         (branch_ex),
        .jump           (jump_ex),
        .funct3         (funct3_ex),
        .pc_src         (pc_src_ex)
    );

    // Note: Assuming ex_mem_reg is updated with rst_or_flush and pc_plus4
    ex_mem_reg ex_mem_inst (
        .clk            (clk),
        .rst_or_flush   (reset),
        // Control IN
        .reg_write_ex   (reg_write_ex),
        .result_src_ex  (result_src_ex),
        .mem_write_ex   (mem_write_ex),
        .mem_read_ex    (mem_read_ex),
        // Data IN
        .alu_result_ex  (alu_result_ex),
        .write_data_ex  (forward_b_val),
        .pc_plus4_ex    (pc_plus4_ex),
        .rd_ex          (rd_ex),
        // Control OUT
        .reg_write_mem  (reg_write_mem),
        .result_src_mem (result_src_mem),
        .mem_write_mem  (mem_write_mem),
        .mem_read_mem   (mem_read_mem),
        // Data OUT
        .alu_result_mem (alu_result_mem),
        .write_data_mem (write_data_mem),
        .pc_plus4_mem   (pc_plus4_mem),
        .rd_mem         (rd_mem)
    );


    // =========================================================================
    // MEMORY (MEM) STAGE
    // =========================================================================

    dmem dmem_inst (
        .clk            (clk),
        .we             (mem_write_mem),
        .addr           (alu_result_mem),
        .wd             (write_data_mem),
        .rd             (read_data_mem)
    );

    // Note: Assuming mem_wb_reg is updated with reset and pc_plus4 passes through
    mem_wb_reg mem_wb_inst (
        .clk            (clk),
        .reset          (reset),
        // Control & Data IN
        .reg_write_mem  (reg_write_mem),
        .result_src_mem (result_src_mem),
        .alu_result_mem (alu_result_mem),
        .read_data_mem  (read_data_mem),
        .pc_plus4_mem   (pc_plus4_mem),
        .rd_mem         (rd_mem),
        // Control & Data OUT
        .reg_write_wb   (reg_write_wb),
        .result_src_wb  (result_src_wb),
        .alu_result_wb  (alu_result_wb),
        .read_data_wb   (read_data_wb),
        .pc_plus4_wb    (pc_plus4_wb),
        .rd_wb          (rd_wb)
    );


    // =========================================================================
    // WRITEBACK (WB) STAGE
    // =========================================================================

    assign result_wb = (result_src_wb == 2'b00) ? alu_result_wb :
                       (result_src_wb == 2'b01) ? read_data_wb  : pc_plus4_wb;

    // Testbench taps
    assign test_we   = mem_write_mem;
    assign test_addr = alu_result_mem;
    assign test_data = write_data_mem;

endmodule
