# RAPIDASH — 5-Stage Pipelined RV32I RISC-V Processor Core

**RAPIDASH** is a 32-bit, in-order, 5-stage pipelined RISC-V processor core implementing the base integer instruction set (**RV32I**), written in **SystemVerilog** and verified using **Verilator** and **GTKWave** on Linux.

---

## Key Architectural Features

- **ISA Support:** Complete RV32I Base Integer Instruction Set (R-type, I-type, S-type, B-type, U-type, and J-type instructions).
- **Modular 5-Stage Pipeline Architecture:**
  1. **IF (Instruction Fetch):** `pc_unit.sv` & `imem.sv` — Program Counter generation, branch/jump target selection, and instruction memory fetch (`firmware.hex`).
  2. **ID (Instruction Decode):** `main_control.sv`, `alu_decoder.sv`, `sign_extend.sv`, & `regfile.sv` — Control signal decoding, immediate sign-extension, and 32x32-bit Register File read (`x0` hardwired to zero).
  3. **EX (Execute):** `alu.sv` & `branch_unit.sv` — 32-bit ALU execution and branch condition evaluation.
  4. **MEM (Memory Access):** `dmem.sv` — Data memory read/write interface supporting byte, half-word, and word operations.
  5. **WB (Writeback):** Result multiplexing (ALU output, Data Memory load, or `PC + 4`) written back to `regfile.sv`.
- **Pipeline Registers:** Dedicated inter-stage state registers (`if_id_reg.sv`, `id_ex_reg.sv`, `ex_mem_reg.sv`, `mem_wb_reg.sv`) with synchronous stall and flush controls.
- **Hazard Management:**
  - **Data Forwarding (`forwarding_unit.sv`):** EX-to-EX and MEM-to-EX bypass paths to resolve RAW (Read-After-Write) data hazards without stalling.
  - **Load-Use & Control Hazard Detection (`hazard_detection_unit.sv`):** Pipeline interlock logic to stall IF/ID on load-use dependencies and flush stages on taken branches/jumps.

---

## Repository Structure

```text
RAPIDASH/
└── rtl/
    ├── top.sv                     # Top-level RV32I processor integration
    ├── pc_unit.sv                 # Program Counter & next-PC logic
    ├── imem.sv                    # Instruction memory (loads firmware.hex)
    ├── if_id_reg.sv               # IF/ID pipeline register
    ├── main_control.sv            # Primary opcode control decoder
    ├── alu_decoder.sv             # ALU operation decoder (funct3/funct7)
    ├── sign_extend.sv             # Immediate generator & sign-extender
    ├── regfile.sv                 # 32x32-bit dual-read, single-write register file
    ├── id_ex_reg.sv               # ID/EX pipeline register
    ├── alu.sv                     # 32-bit Arithmetic Logic Unit
    ├── branch_unit.sv             # Branch comparator & condition evaluator
    ├── ex_mem_reg.sv              # EX/MEM pipeline register
    ├── dmem.sv                    # Data memory module
    ├── mem_wb_reg.sv              # MEM/WB pipeline register
    ├── forwarding_unit.sv         # EX/MEM data forwarding logic
    ├── hazard_detection_unit.sv   # Stall & flush control unit
    ├── tb_top.cpp                 # Verilator C++ testbench & VCD trace driver
    ├── firmware.hex               # Compiled RISC-V machine code memory image
    ├── waveform.vcd               # Generated VCD simulation waveform dump
