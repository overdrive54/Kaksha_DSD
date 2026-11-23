#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vtop.h"

// 2000 ticks = 1000 full clock cycles (since clk toggles every tick)
#define MAX_SIM_TIME 2000

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    // Instantiate the top-level module
    Vtop* dut = new Vtop;

    // Enable VCD tracing
    Verilated::traceEverOn(true);
    VerilatedVcdC* m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5); // Trace 5 levels of hierarchy
    m_trace->open("waveform.vcd");

    vluint64_t sim_time = 0;
    dut->clk = 0;
    dut->reset = 1;

    // Simulation loop
    while (sim_time < MAX_SIM_TIME) {
        // Toggle clock every tick
        dut->clk ^= 1;

        // Release reset after 2 ticks (1 full cycle)
        if (sim_time > 2) {
            dut->reset = 0;
        }

        // Evaluate the combinatorial logic
        dut->eval();

        // Self-Checking Monitor on the rising clock edge
        if (dut->clk == 1 && dut->test_we) {
            // Formatted to hex for better readability of 32-bit values
            printf("[Bus Sniffer] Write to 0x%08X: 0x%08X\n", dut->test_addr, dut->test_data);

            if (dut->test_addr == 0x1000) { // Trap the MMIO address
                if (dut->test_data == 1) {
                    std::cout << "\n[PASS] Pipeline executed flawlessly! Forwarding & Stalls work.\n";
                } else {
                    std::cout << "\n[FAIL] Pipeline test failed. Check your branch or hazard logic.\n";
                }
                m_trace->flush(); // Ensure the final cycle is dumped before breaking
                break;
            }
        }

        // Dump values to VCD
        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}
