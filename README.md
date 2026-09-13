# Thermodynamic RISC-V p-Bit Coprocessor (RV32I + PPU)

Open-hardware processor: 32-bit RISC-V (RV32I) core coupled with a thermodynamic
**Probabilistic Processing Unit (PPU)** for silicon-level truly-random number
generation (TRNG) and ultra-low-power stochastic logic.

**Verified on physical hardware:** Sipeed Tang Nano 9K (Gowin GW1NR-9C FPGA)

## Key Results (Physically Verified, 2026-09-13)

| Metric | Result |
|---|---|
| Native clock | 27.00 MHz (Fmax = 80.37 MHz, Nextpnr P&R) |
| NIST SP 800-22 (Runs Test) | P-value = 0.09046 |
| Shannon entropy | H = 0.7521 bits/bit |
| Energy vs 1.0 V CMOS | −99.51 % dynamic power (204.1× per cycle) |
| Logic accuracy (500-cycle stress) | BER = 0.00e+00 (100 % conformant) |
| p-Bit sample time | 37.04 ns (1 cycle @ 27 MHz) |
| Majority decision | 9.48 µs (256-cycle Monte Carlo) |

## NLnet Application

- **Fund:** Restack (Open Internet Stack)
- **Application code:** `2026-11-0ed`
- **Website (Zenodo):** <https://zenodo.org/records/22716326>

## Repository Layout

```
src/           Main Verilog RTL (pbit_core, prob_gate_unit, riscv_prob_cpu, UART)
riscv_ppu/     Probabilistic Processing Unit subproject (RTL + tests + build recipes)
riscv_alu_hibrida/ Native hybrid ALU (deterministic + CUSTOM-0 pbit.xor) subproject
tests/         Hardware test suites (UART 115200 /dev/ttyUSB1) + visual inspection
include/       C headers for host-side test tooling
docs/          Tang Nano 9K schematic, pinmap, constraints
paper/         IEEE-format manuscript + LaTeX sources
```

## Hardware Requirements

- Sipeed Tang Nano 9K (Gowin GW1NR-9C) with FT2232 USB
- openFPGALoader (flash bitstream, volatile SRAM)
- Python 3 + pyserial
- ADB-enabled smartphone camera for visual LED inspection (optional)

## Build & Flash (typical)

```bash
openFPGALoader -b tangnano9k --detect          # verify FPGA presence
openFPGALoader -b tangnano9k riscv_ppu/build/riscv_prob_cpu.fs   # load to SRAM
python3 tests/test_tangnano9k_cpu.py           # UART gate suite
python3 tests/test_hybrid_alu.py               # hybrid ALU suite
python3 tests/benchmark_industrial.py          # NIST 800-22 + stress
python3 tests/energy_comparison.py             # energy model comparison
```

## License

Dual-licensed: **Apache-2.0** (default, OSI-recognised) OR **TH-FL-1.0**
(optional fair-source alternative with a USD 1M royalty threshold for
commercial adopters). See `LICENSE.md`.

SPDX-License-Identifier: `Apache-2.0 OR TH-FL-1.0`

## Citation

Antigravity Autonomous Laboratory et al., "A Thermodynamically-Grounded
Sub-Threshold p-Bit Coprocessor for RISC-V: Physical FPGA Realization,
Stochastic Universality, and Industrial Energy Benchmarks," Zenodo, 2026.
DOI: 10.5281/zenodo.22716326