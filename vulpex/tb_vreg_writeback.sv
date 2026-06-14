`timescale 1ns / 1ps

module tb_vreg_writeback;

    // ---------------------------------------------------------
    // 1. PARAMETERS & INTERFACE DEFINITIONS
    // ---------------------------------------------------------
    localparam int unsigned NUM_LANES = 4;
    localparam int unsigned VREG_W    = 128;
    localparam int unsigned VREG_D    = 32;
    localparam int unsigned RD_PORTS  = 2;
    localparam int unsigned WR_PORTS  = 2;

    localparam int unsigned LANE_W    = VREG_W / NUM_LANES;
    localparam int unsigned LANE_BE   = LANE_W / 8;
    localparam int unsigned ADDR_W    = $clog2(VREG_D);

    // Clock and Reset
    logic clk;
    //logic reset_n;

    // DUT Signals
    logic [RD_PORTS-1:0][ADDR_W-1:0]                  rd_addr;
    logic [RD_PORTS-1:0][NUM_LANES-1:0][LANE_W-1:0]   rd_data;

    logic                                             valid_compute;
    logic [ADDR_W-1:0]                                addr_compute;
    logic [NUM_LANES-1:0][LANE_W-1:0]                 data_compute;
    logic [NUM_LANES-1:0][LANE_BE-1:0]                be_compute;

    logic                                             valid_lsu;
    logic [ADDR_W-1:0]                                addr_lsu;
    logic [NUM_LANES-1:0][LANE_W-1:0]                 data_lsu;
    logic [NUM_LANES-1:0][LANE_BE-1:0]                be_lsu;

    logic                                             stall_lsu;

    // ---------------------------------------------------------
    // 2. DUT INSTANTIATION
    // ---------------------------------------------------------
    vreg_writeback_stage #(
        .NUM_LANES(NUM_LANES),
        .VREG_W(VREG_W),
        .VREG_D(VREG_D),
        .RD_PORTS(RD_PORTS),
        .WR_PORTS(WR_PORTS)
    ) dut (
        .clk_i           (clk),
        .rd_addr_i       (rd_addr),
        .rd_data_o       (rd_data),
        .valid_compute_i (valid_compute),
        .addr_compute_i  (addr_compute),
        .data_compute_i  (data_compute),
        .be_compute_i    (be_compute),
        .valid_lsu_i     (valid_lsu),
        .addr_lsu_i      (addr_lsu),
        .data_lsu_i      (data_lsu),
        .be_lsu_i        (be_lsu),
        .stall_lsu_o     (stall_lsu)
    );

    // Clock Generator (100MHz)
    always #5 clk = ~clk;

    // ---------------------------------------------------------
    // 3. SCOREBOARD & REFERENCE MODEL CLASS
    // ---------------------------------------------------------
    class Scoreboard;
        // Golden memory model mirroring the structural layout of the DUT
        logic [LANE_W-1:0] ref_mem [NUM_LANES][VREG_D];
        
        // Internal tracking of pipelined read addresses
        logic [RD_PORTS-1:0][ADDR_W-1:0] pipe_rd_addr;

        // NEW: Track expected read data before writes occur in the same cycle
        logic [RD_PORTS-1:0][NUM_LANES-1:0][LANE_W-1:0] expected_rd_data;

        // Statistics
        int total_tests     = 0;
        int passed_tests    = 0;
        int failed_tests    = 0;
        int hazard_stalls   = 0;

        function new();
            // Initialize memory to 0
            for(int l=0; l<NUM_LANES; l++) begin
                for(int r=0; r<VREG_D; r++) begin
                    ref_mem[l][r] = '0;
                end
            end
            pipe_rd_addr = '0;
            expected_rd_data = '0;
        endfunction

        // Predicts internal state modifications based on input stimuli
        function void update_model(
            input logic        v_comp,  input logic [ADDR_W-1:0]  addr_comp, input logic [NUM_LANES-1:0][LANE_W-1:0]  data_comp, input logic [NUM_LANES-1:0][LANE_BE-1:0]  be_comp,
            input logic        v_lsu,   input logic [ADDR_W-1:0]  addr_lsu,  input logic [NUM_LANES-1:0][LANE_W-1:0]  data_lsu,  input logic [NUM_LANES-1:0][LANE_BE-1:0]  be_lsu,
            input logic [RD_PORTS-1:0][ADDR_W-1:0] current_rd_addr
        );
            logic actual_stall;
            logic bytes_overlap;

            // ---------------------------------------------------------
            // NEW: SAMPLE READS FIRST 
            // Model BRAM latency behavior (old-data read before write applies)
            // ---------------------------------------------------------
            for (int p=0; p<RD_PORTS; p++) begin
                for (int l=0; l<NUM_LANES; l++) begin
                    expected_rd_data[p][l] = ref_mem[l][current_rd_addr[p]];
                end
            end
            pipe_rd_addr = current_rd_addr;

            // Check if Hazard Detector should trigger a stall
            bytes_overlap = |({be_comp} & {be_lsu});
            actual_stall  = v_comp && v_lsu && (addr_comp == addr_lsu) && bytes_overlap;

            if (actual_stall) hazard_stalls++;

            // Port 0 (Compute) Update
            if (v_comp) begin
                for (int l=0; l<NUM_LANES; l++) begin
                    for (int b=0; b<LANE_BE; b++) begin
                        if (be_comp[l][b]) begin
                            ref_mem[l][addr_comp][b*8 +: 8] = data_comp[l][b*8 +: 8];
                        end
                    end
                end
            end

            // Port 1 (LSU) Update - Only runs if NOT gated by a hazard stall
            if (v_lsu && !actual_stall) begin
                for (int l=0; l<NUM_LANES; l++) begin
                    for (int b=0; b<LANE_BE; b++) begin
                        // Port 0 structural priority override
                        if (v_comp && (addr_comp == addr_lsu) && be_comp[l][b]) begin
                            // Gated out by structural design priority (though stall handles overlaps)
                        end else if (be_lsu[l][b]) begin
                            ref_mem[l][addr_lsu][b*8 +: 8] = data_lsu[l][b*8 +: 8];
                        end
                    end
                end
            end

            total_tests++;
        endfunction

        // Verifies output read data matches reference arrays
        function void check_outputs(input logic [RD_PORTS-1:0][NUM_LANES-1:0][LANE_W-1:0] dut_rd_data, input logic dut_stall);
            logic error_found = 0;

            for (int p=0; p<RD_PORTS; p++) begin
                for (int l=0; l<NUM_LANES; l++) begin
                    // MODIFIED: Compare against the expected_rd_data we sampled BEFORE the writes occurred
                    if (dut_rd_data[p][l] !== expected_rd_data[p][l]) begin
                        $display("[ERROR] Mismatch on Port %0d, Lane %0d! Expected: 0x%h, Got: 0x%h", 
                                  p, l, expected_rd_data[p][l], dut_rd_data[p][l]);
                        error_found = 1;
                    end
                end
            end

            if (error_found) failed_tests++;
            else             passed_tests++;
        endfunction

        // Print final status metrics
        function void print_scoreboard();
            $display("\n=======================================================");
            $display("                VREG WRITEBACK SCOREBOARD              ");
            $display("=======================================================");
            $display("  Total Operations Checked : %0d", total_tests);
            $display("  Passed Checks            : %0d", passed_tests);
            $display("  Failed Checks            : %0d", failed_tests);
            $display("  Hazard Stalls Observed   : %0d", hazard_stalls);
            if (failed_tests == 0) begin
                $display("  STATUS                   : PASSED SUCCESSFULLY ✅");
            end else begin
                $display("  STATUS                   : FAILED WITH ERRORS ❌");
            end
            $display("=======================================================\n");
        endfunction
    endclass

    Scoreboard sb;

    // ---------------------------------------------------------
    // 4. TEST STIMULUS RUNTIME
    // ---------------------------------------------------------
    initial begin
        sb = new();
        
        // Initialize Inputs
        clk           = 0;
        //reset_n       = 0;
        rd_addr       = '0;
        valid_compute = 0; addr_compute = '0; data_compute = '0; be_compute = '0;
        valid_lsu     = 0; addr_lsu     = '0; data_lsu     = '0; be_lsu     = '0;

        repeat (2) @(posedge clk);
        //reset_n = 1;
        @(posedge clk);

        $display("[TB INFO] Starting Corner Case Structural Asserts...");

        // --- CORNER CASE 1: Split-lane/Byte-isolated Concurrent Write (No Hazard) ---
        valid_compute = 1'b1; addr_compute = 5; be_compute = '0; be_compute[0] = '1; // Lane 0 Active
        data_compute  = '0; data_compute[0] = {LANE_W/4{4'hA}}; 
        
        valid_lsu     = 1'b1; addr_lsu     = 5; be_lsu     = '0; be_lsu[1]     = '1; // Lane 1 Active
        data_lsu      = '0; data_lsu[1]    = {LANE_W/4{4'hB}};

        // Track state change inside monitor loop
        step_cycle();

        // --- CORNER CASE 2: Explicit Byte-Overlapping Structural Hazard (Stall Expected) ---
        valid_compute = 1'b1; addr_compute = 5; be_compute = '0; be_compute[0][0] = 1'b1;
        data_compute  = '0; data_compute[0][7:0] = 8'h99;

        valid_lsu     = 1'b1; addr_lsu     = 5; be_lsu     = '0; be_lsu[0][0]     = 1'b1;
        data_lsu      = '0; data_lsu[0][7:0]    = 8'hFF;
        
        step_cycle();
        if (!stall_lsu) $display("[ERROR] Expected hazard stall failed to assert on explicit overlapping byte lanes.");

        // Clear triggers 
        valid_compute = 0; valid_lsu = 0;
        step_cycle();

        // --- CORNER CASE 3: Simultaneous Back-to-Back Verification via Reads ---
        rd_addr[0] = 5; // Check register 5 updates
        step_cycle();   // Register address input
        step_cycle();   // Verify read alignment evaluation

        // ---------------------------------------------------------
        // 5. CONSTRAINED RANDOM TESTING (CRV)
        // ---------------------------------------------------------
        $display("[TB INFO] Starting Constrained Random Testing Loop (500 Iterations)...");
        
        for (int i = 0; i < 500; i++) begin
            // Randomly drive inputs using system functions to maximize edge scenarios
            valid_compute = $urandom_range(0, 1);
            addr_compute  = $urandom_range(0, VREG_D-1);
            be_compute    = {$urandom, $urandom}; // Distribute random bits across dynamic width
            
            for (int l=0; l<NUM_LANES; l++) begin
                for (int b=0; b<LANE_BE; b++) begin
                    data_compute[l][b*8 +: 8] = $urandom;
                end
            end

            // 50% probability to force address/lane intersection conditions
            if ($urandom_range(0, 1)) begin
                addr_lsu = addr_compute; // Force identical register lookup hazard checking
            end else begin
                addr_lsu = $urandom_range(0, VREG_D-1);
            end

            valid_lsu     = $urandom_range(0, 1);
            be_lsu        = {$urandom, $urandom};
            
            for (int l=0; l<NUM_LANES; l++) begin
                for (int b=0; b<LANE_BE; b++) begin
                    data_lsu[l][b*8 +: 8] = $urandom;
                end
            end

            // Drive Random Multi-Port Read Adresses
            for (int p=0; p<RD_PORTS; p++) begin
                rd_addr[p] = $urandom_range(0, VREG_D-1);
            end

            step_cycle();
        end

        // Wind down system processing for read pipelined updates
        valid_compute = 0; valid_lsu = 0;
        repeat(5) step_cycle();

        // Print Out Result Verification Status Table
        sb.print_scoreboard();
        $finish;
    end

    // ---------------------------------------------------------
    // 6. HELPER ENVIRONMENT TASK
    // ---------------------------------------------------------
    task step_cycle();
        // Sample right before the edge clock modifications occur
        sb.update_model(
            valid_compute, addr_compute, data_compute, be_compute,
            valid_lsu, addr_lsu, data_lsu, be_lsu,
            rd_addr
        );
        @(posedge clk);
        #1; // Minor sampling offset delay to account for comb evaluation settle time
        sb.check_outputs(rd_data, stall_lsu);
    endtask

endmodule
