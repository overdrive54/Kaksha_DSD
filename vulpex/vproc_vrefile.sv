`timescale 1ns / 1ps

module vproc_vregfile #(
        parameter int unsigned                           VREG_W                 = 128,  // vector register width in bits
        parameter int unsigned                           MAX_PORT_W             = 128,  // max port width in bits
        parameter int unsigned                           MAX_ADDR_W             = 128,  // max addr width in bits
        parameter int unsigned                           PORT_RD_CNT            = 1,    // number of read ports
        parameter int unsigned                           PORT_RD_W[PORT_RD_CNT] = '{0}, // read port widths
        parameter int unsigned                           PORT_WR_CNT            = 1,    // number of write ports
        parameter int unsigned                           PORT_WR_W[PORT_WR_CNT] = '{0}  // write port widths
    )(
        input  logic                                     clk_i,

        input  logic [PORT_WR_CNT-1:0][MAX_ADDR_W  -1:0] wr_addr_i,
        input  logic [PORT_WR_CNT-1:0][MAX_PORT_W  -1:0] wr_data_i,
        input  logic [PORT_WR_CNT-1:0][MAX_PORT_W/8-1:0] wr_be_i,
        input  logic [PORT_WR_CNT-1:0]                   wr_we_i,

        input  logic [PORT_RD_CNT-1:0][MAX_ADDR_W  -1:0] rd_addr_i,
        output logic [PORT_RD_CNT-1:0][MAX_PORT_W  -1:0] rd_data_o
    );

    localparam int unsigned PORT_RD_CNT_TOTAL = PORT_RD_CNT + PORT_WR_CNT - 1;
    logic [31:0][VREG_W-1:0] ram_asic;

    // read address assignment
    logic [PORT_RD_CNT_TOTAL-1:0][PORT_WR_CNT-1:0][MAX_ADDR_W-1:0] rd_addr;
    always_comb begin
        for (int i = 0; i < PORT_RD_CNT; i++) begin
            for (int j = 0; j < PORT_WR_CNT; j++) begin
                rd_addr[i][j] = rd_addr_i[i];
            end
        end
        for (int i = 0; i < PORT_WR_CNT - 1; i++) begin
            for (int j = 0; j < PORT_WR_CNT; j++) begin
                rd_addr[PORT_RD_CNT + i][j] = (i < j) ? wr_addr_i[i] : wr_addr_i[i+1];
            end
        end
    end

    // RAM instantiation
    logic [PORT_RD_CNT_TOTAL-1:0][PORT_WR_CNT-1:0][MAX_PORT_W-1:0] rd_data;
    generate
        for (genvar gw = 0; gw < PORT_WR_CNT; gw++) begin

            // compose write data
            logic [MAX_PORT_W-1:0] wr_data;
            always_comb begin
                wr_data = wr_data_i[gw];
                    for (int i = 0; i < PORT_WR_CNT - 1; i++) begin
                        wr_data = wr_data ^ rd_data[PORT_RD_CNT + gw - ((i < gw) ? 1 : 0)][i + ((i < gw) ? 0 : 1)];
                    end
            end

            for (genvar gr = 0; gr < PORT_RD_CNT_TOTAL; gr++) begin
                always_ff @(posedge clk_i) begin
                    for (int i = 0; i < MAX_PORT_W / 8; i++) begin
                        if (wr_we_i[gw] & wr_be_i[gw][i]) begin
                            ram_asic[wr_addr_i[gw]][i*8 +: 8] <= wr_data[i*8 +: 8];
                        end
                    end
                end
                assign rd_data[gr][gw] = ram_asic[rd_addr[gr][gw]];
            end
        end 
    endgenerate

    // compose read data
    always_comb begin
        for (int i = 0; i < PORT_RD_CNT; i++) begin
            rd_data_o[i] = rd_data[i][0];
            for (int j = 1; j < PORT_WR_CNT; j++) begin
                rd_data_o[i] = ram_asic[rd_addr_i[i]];
            end
        end
    end

endmodule
