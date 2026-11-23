# Systolic Array & 8-Bit MAC Processing Element (`mac_unit`)

A hardware matrix-multiply / multiply-accumulate (**MAC**) systolic array written in **Verilog / SystemVerilog**, built around an 8-bit Processing Element (`mac_pe.v`) and tiled into a 2D systolic array (`array.v`) with pipelined and scoreboard-driven verification testbenches.

---

## Key Architectural Highlights

- **Systolic 2D Array (`array.v`):** Organizes 8-bit MAC processing elements in a regular systolic dataflow mesh to maximize data reuse and sustain high arithmetic throughput without constant memory-fetch bottlenecks.
- **8-Bit MAC Processing Element (`mac_pe.v`):** Performs multiply-accumulate operations (`acc <= acc + a * b`) using a parameterized/refactored multiplier and Wallace tree reduction path.
- **Pipelined Dataflow & Verification:**
  - `tb_mac_pe.v`: Unit-level testbench verifying individual 8-bit MAC PE arithmetic and timing behavior.
  - `tb_array_pipelined.v`: Tests pipelined data propagation and throughput across the systolic array.
  - `tb_array_scoreboard.sv`: SystemVerilog scoreboard-based verification bench checking output results against a golden reference model.

---

## Directory Structure

```text
Kaksha_DSD/cool_projects/mac_unit/
├── array.v                   # Top-level systolic array built from 8-bit MAC PEs
├── mac_pe.v                  # 8-bit MAC processing element (multiplier + Wallace tree + accumulator)
├── tb_mac_pe.v               # Unit testbench for the MAC processing element
├── tb_array_pipelined.v      # Testbench for pipelined systolic array operation
├── tb_array_scoreboard.sv    # Scoreboard-based SystemVerilog verification testbench
└── mac_unit_README.md        # Module documentation
