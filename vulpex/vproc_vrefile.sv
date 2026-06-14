`timescale 1ns / 1ps

module vector_hazard_detector #(
    parameter int unsigned NUM_LANES = 4,
    parameter int unsigned VREG_D    = 32,
    parameter int unsigned VREG_W    = 128
)(
    // Instruction 0 (e.g., Vector Compute - High Priority)
    input  logic                                            valid_0_i,
    input  logic [$clog2(VREG_D)-1:0]                       dest_reg_0_i,
    input  logic [NUM_LANES-1:0][(VREG_W/NUM_LANES)/8-1:0] byte_en_0_i,

    // Instruction 1 (e.g., Load/Store Unit - Lower Priority)
    input  logic                                            valid_1_i,
    input  logic [$clog2(VREG_D)-1:0]                       dest_reg_1_i,
    input  logic [NUM_LANES-1:0][(VREG_W/NUM_LANES)/8-1:0] byte_en_1_i,

    // Hazard Control Signals
    output logic                                            stall_1_o  // Tells the LSU to wait 1 cycle
);

    logic same_register;
    logic bytes_overlap;

    always_comb begin
        // 1. Are they targeting the exact same register?
        same_register = (dest_reg_0_i == dest_reg_1_i);

        // 2. The Bitwise AND Check
        // REFACTOR: Explicitly flatten the 2D arrays into 1D bitstreams using {...} 
        // to guarantee tool portability across strict ASIC and FPGA synthesisers.
        bytes_overlap = |({byte_en_0_i} & {byte_en_1_i});

        // 3. Generate the Stall
        if (valid_0_i && valid_1_i && same_register && bytes_overlap) begin
            stall_1_o = 1'b1; 
        end else begin
            stall_1_o = 1'b0; 
        end
    end

endmodule

module vreg #(
    parameter int unsigned NUM_LANES = 4,   // Number of parallel execution lanes
    parameter int unsigned VREG_W    = 512, // Total vector register width in bits
    parameter int unsigned VREG_D    = 32,  // Number of vector registers (depth)
    parameter int unsigned RD_PORTS  = 2,   // e.g., 2 for ALU, 1 for LSU
    parameter int unsigned WR_PORTS  = 2    // e.g., 1 for ALU, 1 for LSU
)(
    input  logic clk_i,

    // Read Ports
    input  logic [RD_PORTS-1:0][$clog2(VREG_D)-1:0]                    rd_addr_i,
    output logic [RD_PORTS-1:0][NUM_LANES-1:0][(VREG_W/NUM_LANES)-1:0] rd_data_o,

    // Write Ports
    input  logic [WR_PORTS-1:0]                                        wr_en_i,
    input  logic [WR_PORTS-1:0][$clog2(VREG_D)-1:0]                    wr_addr_i,
    input  logic [WR_PORTS-1:0][NUM_LANES-1:0][(VREG_W/NUM_LANES)-1:0] wr_data_i,
    input  logic [WR_PORTS-1:0][NUM_LANES-1:0][(VREG_W/NUM_LANES)/8-1:0] wr_be_i 
);

    localparam int unsigned LANE_W  = VREG_W / NUM_LANES;
    localparam int unsigned LANE_BE = LANE_W / 8;
    localparam int unsigned ADDR_W  = $clog2(VREG_D);

    // -------------------------------------------------------------------------
    // 1. Memory Arrays: Segregated per Lane
    // -------------------------------------------------------------------------

    logic [LANE_W-1:0] lane_mem [NUM_LANES][VREG_D];

    initial begin
        for (int l = 0; l < NUM_LANES; l++) begin
            for (int r = 0; r < VREG_D; r++) begin
                lane_mem[l][r] = '0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // 2. Write Logic: Structured to eliminate cross-port assignment interference
    // -------------------------------------------------------------------------
    always_ff @(posedge clk_i) begin
        for (int l = 0; l < NUM_LANES; l++) begin
            for (int b = 0; b < LANE_BE; b++) begin
                if (wr_en_i[0] && wr_be_i[0][l][b]) begin
                    lane_mem[l][wr_addr_i[0]][b*8 +: 8] <= wr_data_i[0][l][b*8 +: 8];
                end
                if (wr_en_i[1] && wr_be_i[1][l][b]) begin
                    lane_mem[l][wr_addr_i[1]][b*8 +: 8] <= wr_data_i[1][l][b*8 +: 8];
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // 3. Read Logic: Synchronous Memory Lookup
    // -------------------------------------------------------------------------
    always @(posedge clk_i) begin
        for (int p = 0; p < RD_PORTS; p++) begin
            for (int l = 0; l < NUM_LANES; l++) begin
                rd_data_o[p][l] = lane_mem[l][rd_addr_i[p]];
            end
        end
    end

endmodule

module vreg_writeback_stage #(
    parameter int unsigned NUM_LANES = 4,
    parameter int unsigned VREG_W    = 128,
    parameter int unsigned VREG_D    = 32,
    parameter int unsigned RD_PORTS  = 2,
    parameter int unsigned WR_PORTS  = 2
)(
    input  logic clk_i,
    //input  logic reset_ni, // Kept on top-level boundary for system compatibility

    // ==========================================
    // READ INTERFACE (Pass-through to RF)
    // ==========================================
    input  logic [RD_PORTS-1:0][$clog2(VREG_D)-1:0]                    rd_addr_i,
    output logic [RD_PORTS-1:0][NUM_LANES-1:0][(VREG_W/NUM_LANES)-1:0] rd_data_o,

    // ==========================================
    // WRITE PORT 0: COMPUTE UNIT (High Priority)
    // ==========================================
    input  logic                                                       valid_compute_i,
    input  logic [$clog2(VREG_D)-1:0]                                  addr_compute_i,
    input  logic [NUM_LANES-1:0][(VREG_W/NUM_LANES)-1:0]               data_compute_i,
    input  logic [NUM_LANES-1:0][(VREG_W/NUM_LANES)/8-1:0]             be_compute_i,

    // ==========================================
    // WRITE PORT 1: LOAD/STORE UNIT (Lower Priority)
    // ==========================================
    input  logic                                                       valid_lsu_i,
    input  logic [$clog2(VREG_D)-1:0]                                  addr_lsu_i,
    input  logic [NUM_LANES-1:0][(VREG_W/NUM_LANES)-1:0]               data_lsu_i,
    input  logic [NUM_LANES-1:0][(VREG_W/NUM_LANES)/8-1:0]             be_lsu_i,

    // ==========================================
    // PIPELINE CONTROL OUTPUTS
    // ==========================================
    output logic                                                       stall_lsu_o
);

    // Internal signals for mapping to the generic RF WR_PORTS arrays
    logic [WR_PORTS-1:0]                                         rf_wr_en;
    logic [WR_PORTS-1:0][$clog2(VREG_D)-1:0]                      rf_wr_addr;
    logic [WR_PORTS-1:0][NUM_LANES-1:0][(VREG_W/NUM_LANES)-1:0]   rf_wr_data;
    logic [WR_PORTS-1:0][NUM_LANES-1:0][(VREG_W/NUM_LANES)/8-1:0] rf_wr_be;

    // ---------------------------------------------------------
    // 1. INSTANTIATE HAZARD DETECTOR
    // ---------------------------------------------------------
    vector_hazard_detector #(
        .NUM_LANES(NUM_LANES),
        .VREG_D(VREG_D),
        .VREG_W(VREG_W)
    ) hazard_unit (
        .valid_0_i    (valid_compute_i),
        .dest_reg_0_i (addr_compute_i),
        .byte_en_0_i  (be_compute_i),
        
        .valid_1_i    (valid_lsu_i),
        .dest_reg_1_i (addr_lsu_i),
        .byte_en_1_i  (be_lsu_i),
        
        .stall_1_o    (stall_lsu_o)
    );

    // ---------------------------------------------------------
    // 2. WRITE-ENABLE GATING LOGIC
    // ---------------------------------------------------------
    always_comb begin
        rf_wr_en[0]   = valid_compute_i;
        rf_wr_addr[0] = addr_compute_i;
        rf_wr_data[0] = data_compute_i;
        rf_wr_be[0]   = be_compute_i;

        rf_wr_en[1]   = valid_lsu_i & ~stall_lsu_o; 
        rf_wr_addr[1] = addr_lsu_i;
        rf_wr_data[1] = data_lsu_i;
        rf_wr_be[1]   = be_lsu_i;
    end

    // ---------------------------------------------------------
    // 3. INSTANTIATE THE REGISTER FILE (7-Port BRAM Variant)
    // ---------------------------------------------------------
    vreg #(
        .NUM_LANES(NUM_LANES),
        .VREG_W(VREG_W),
        .VREG_D(VREG_D),
        .RD_PORTS(RD_PORTS),
        .WR_PORTS(WR_PORTS)
    ) regfile_core (
        .clk_i       (clk_i),
                
        .rd_addr_i   (rd_addr_i),
        .rd_data_o   (rd_data_o),
        
        .wr_en_i     (rf_wr_en),
        .wr_addr_i   (rf_wr_addr),
        .wr_data_i   (rf_wr_data),
        .wr_be_i     (rf_wr_be)
    );

endmodule
