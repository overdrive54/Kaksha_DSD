`timescale 1ns / 1ps

module tb_vreg_writeback();

    // ==========================================
    // 1. Parameters & Signals
    // ==========================================
    localparam NUM_LANES = 4;
    localparam VREG_W    = 128;
    localparam VREG_D    = 32;
    localparam RD_PORTS  = 3;
    localparam WR_PORTS  = 2;
    
    localparam LANE_W  = VREG_W / NUM_LANES;
    localparam LANE_BE = LANE_W / 8;
    localparam ADDR_W  = $clog2(VREG_D);

    logic clk;
    logic reset_n;

    // Read Ports
    logic [RD_PORTS-1:0][ADDR_W-1:0]               rd_addr;
    logic [RD_PORTS-1:0][NUM_LANES-1:0][LANE_W-1:0] rd_data;

    // Write Port 0 (Compute)
    logic                                          valid_comp;
    logic [ADDR_W-1:0]                             addr_comp;
    logic [NUM_LANES-1:0][LANE_W-1:0]              data_comp;
    logic [NUM_LANES-1:0][LANE_BE-1:0]             be_comp;

    // Write Port 1 (LSU)
    logic                                          valid_lsu;
    logic [ADDR_W-1:0]                             addr_lsu;
    logic [NUM_LANES-1:0][LANE_W-1:0]              data_lsu;
    logic [NUM_LANES-1:0][LANE_BE-1:0]             be_lsu;
    logic                                          stall_lsu;

    // ==========================================
    // 2. The Golden Model (Scoreboard Memory)
    // ==========================================
    // Addressed as: expected_mem[Register][Lane]
    logic [LANE_W-1:0] expected_mem [VREG_D][NUM_LANES];
    int error_count = 0;
    int test_count  = 0;

    // ==========================================
    // 3. DUT Instantiation
    // ==========================================
    vreg_writeback_stage #(
        .NUM_LANES(NUM_LANES), .VREG_W(VREG_W), .VREG_D(VREG_D),
        .RD_PORTS(RD_PORTS), .WR_PORTS(WR_PORTS)
    ) dut (
        .clk_i(clk), .reset_ni(reset_n),
        .rd_addr_i(rd_addr), .rd_data_o(rd_data),
        
        .valid_compute_i(valid_comp), .addr_compute_i(addr_comp), 
        .data_compute_i(data_comp),   .be_compute_i(be_comp),
        
        .valid_lsu_i(valid_lsu),     .addr_lsu_i(addr_lsu), 
        .data_lsu_i(data_lsu),       .be_lsu_i(be_lsu),
        .stall_lsu_o(stall_lsu)
    );

    // ==========================================
    // 4. Clock Generation & Scoreboard Logic
    // ==========================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // Cycle-Accurate Scoreboard Tracker
    // This perfectly mimics the DUT's hazard logic and memory updates
    always_ff @(posedge clk) begin
        if (reset_n) begin
            // 1. Process Compute Write (Always writes if valid)
            if (valid_comp) begin
                for (int l=0; l<NUM_LANES; l++) begin
                    for (int b=0; b<LANE_BE; b++) begin
                        if (be_comp[l][b]) 
                            expected_mem[addr_comp][l][b*8 +: 8] <= data_comp[l][b*8 +: 8];
                    end
                end
            end
            
            // 2. Process LSU Write (Only writes if valid AND NOT stalled by hazard)
            if (valid_lsu && !stall_lsu) begin
                for (int l=0; l<NUM_LANES; l++) begin
                    for (int b=0; b<LANE_BE; b++) begin
                        if (be_lsu[l][b]) 
                            expected_mem[addr_lsu][l][b*8 +: 8] <= data_lsu[l][b*8 +: 8];
                    end
                end
            end
        end
    end

    // ==========================================
    // 5. Verification Tasks
    // ==========================================
    
    // Task: Clear all inputs
    task clear_inputs();
        valid_comp = 0; addr_comp = '0; data_comp = '0; be_comp = '0;
        valid_lsu  = 0; addr_lsu  = '0; data_lsu  = '0; be_lsu  = '0;
        rd_addr = '0;
    endtask

    // Task: Self-Checking Read
    task check_register(input logic [ADDR_W-1:0] addr);
        rd_addr[0] = addr;
        #1; // Wait a delta cycle for combinational read
        
        for (int l=0; l<NUM_LANES; l++) begin
            test_count++;
            if (rd_data[0][l] !== expected_mem[addr][l]) begin
                $error("Time %0t | Mismatch Reg %0d Lane %0d! EXP: %h, GOT: %h", 
                       $time, addr, l, expected_mem[addr][l], rd_data[0][l]);
                error_count++;
            end
        end
    endtask

    // ==========================================
    // 6. Main Test Sequence
    // ==========================================
    initial begin
        // Initialize Golden Model
        for(int r=0; r<VREG_D; r++) 
            for(int l=0; l<NUM_LANES; l++) 
                expected_mem[r][l] = '0;

        reset_n = 0;
        clear_inputs();
        @(posedge clk);
        reset_n = 1;
        @(posedge clk);

        // -----------------------------------------------------
        $display("--- PHASE 1: Corner Cases (Brute Force) ---");
        // -----------------------------------------------------
        
        // TEST A: Total Collision (WAW Hazard)
        // Expectation: stall_lsu goes HIGH. Compute writes, LSU is dropped.
        valid_comp = 1; addr_comp = 5'd1; be_comp = '1; data_comp = '{default: 32'hAAAA_AAAA};
        valid_lsu  = 1; addr_lsu  = 5'd1; be_lsu  = '1; data_lsu  = '{default: 32'hBBBB_BBBB};
        @(posedge clk);
        if (stall_lsu !== 1'b1) $error("FAILED: Hazard Detector missed total collision!");
        clear_inputs();
        @(posedge clk);
        check_register(5'd1); // Should contain AAAA_AAAA, not BBBB_BBBB

        // TEST B: The "Swiss Cheese" Merge (No Hazard)
        // Expectation: stall_lsu goes LOW. Both write safely to different lanes.
        valid_comp = 1; addr_comp = 5'd2; 
        be_comp = '{4'b0000, 4'b0000, 4'b1111, 4'b1111}; // Compute writes Lanes 0, 1
        data_comp = '{default: 32'hCCCC_CCCC};
        
        valid_lsu  = 1; addr_lsu  = 5'd2; 
        be_lsu  = '{4'b1111, 4'b1111, 4'b0000, 4'b0000}; // LSU writes Lanes 2, 3
        data_lsu  = '{default: 32'hDDDD_DDDD};
        
        @(posedge clk);
        if (stall_lsu !== 1'b0) $error("FAILED: Hazard Detector stalled a safe byte-merge!");
        clear_inputs();
        @(posedge clk);
        check_register(5'd2); // Should contain a mix of CCCC and DDDD

        // -----------------------------------------------------
        $display("--- PHASE 2: Constrained Random Verification ---");
        // -----------------------------------------------------
        for (int i = 0; i < 500; i++) begin
            // Randomize inputs
            valid_comp = $urandom_range(0, 1);
            addr_comp  = $urandom_range(0, VREG_D-1);
            be_comp    = $urandom();
            for(int l=0; l<NUM_LANES; l++) data_comp[l] = $urandom();

            valid_lsu  = $urandom_range(0, 1);
            addr_lsu   = $urandom_range(0, VREG_D-1);
            be_lsu     = $urandom();
            for(int l=0; l<NUM_LANES; l++) data_lsu[l] = $urandom();

            @(posedge clk);
        end
        clear_inputs();
        @(posedge clk);

        // -----------------------------------------------------
        $display("--- PHASE 3: Random Memory Verification ---");
        // -----------------------------------------------------
        // Read back every single register and lane to check against the scoreboard
        for (int r = 0; r < VREG_D; r++) begin
            check_register(r);
            @(posedge clk);
        end

        // -----------------------------------------------------
        if (error_count == 0) 
            $display("--- SUCCESS! %0d checks passed with 0 errors. ---", test_count);
        else 
            $display("--- FAILED! Found %0d errors in %0d checks. ---", error_count, test_count);

        $finish;
    end

endmodule
