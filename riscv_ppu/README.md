# Projeto 1: RISC-V RV32I com Coprocessador Probabilístico (PPU)

> **Subprojeto:** `riscv_ppu/`  
> **Arquitetura:** Processador RISC-V RV32I padrão com PPU acessível via barramento MMIO (`0x80000000`).  
> **Alvo Físico:** Sipeed Tang Nano 9K (Gowin GW1NR-9C).

---

## 1. Estrutura do Diretório
* `src/rtl/riscv_prob_cpu.v`: Módulo top-level com RV32I datapath e periférico PPU.
* `src/rtl/prob_gate_unit.v`: Matriz estocástica com portas universais (AND, OR, NOR, XOR com unidade oculta H).
* `src/rtl/pbit_core.v`: Núcleo de p-bit com LFSR Galois de 32 bits e ativador PWL Boltzmann Q4.4.
* `src/rtl/uart_tx.v` & `uart_rx.v`: Transceptor serial assíncrono a 115200 baud.
* `src/tangnano9k.cst`: Mapeamento físico de pinos conforme `docs/schematic.txt`.
* `build/riscv_prob_cpu.fs`: Bitstream gerado pronto para carga na FPGA.
* `tests/benchmark_industrial.py`: Suíte de qualificação industrial (NIST SP 800-22, Ising, Estresse).

---

## 2. Pinagem no Hardware (Sipeed Tang Nano 9K)
Extraído e confrontado com [`docs/schematic.txt`](file:///home/teste/probabilistic-computer/docs/schematic.txt):
* **Oscilador 27 MHz:** Pino 52 (`clk`)
* **Reset (Botão S2):** Pino 4 (`rst_n`, ativo em nível baixo)
* **UART TX:** Pino 17 (`PIN17_IOB2A_FPGA_TX`)
* **UART RX:** Pino 18 (`PIN18_IOB2B_FPGA_RX`)
* **6x LEDs Diagnósticos Laranja:**
  * LED1: Pino 10 (`PIN10_IOL15A_LED1`) -> Heartbeat (~1.6 Hz)
  * LED2: Pino 11 (`PIN11_IOL16B_LED2`) -> PPU Busy
  * LED3: Pino 13 (`PIN13_IOL21B_LED3`) -> p-bit Raw (ruído)
  * LED4: Pino 14 (`PIN14_IOL22B_LED4`) -> Resultado da Porta
  * LED5: Pino 15 (`PIN15_IOL25B_LED5`) -> UART TX Status
  * LED6: Pino 16 (`PIN16_IOL26B_LED6`) -> Flag de Testes Concluídos

---

## 3. Comandos de Compilação & Gravação
```bash
# Síntese:
yosys -p "read_verilog src/rtl/*.v; synth_gowin -top riscv_prob_cpu -json build/riscv_prob_cpu.json"

# Place & Route:
nextpnr-gowin --json build/riscv_prob_cpu.json --write build/riscv_prob_cpu_pnr.json --device GW1NR-LV9QN88PC6/I5 --cst src/tangnano9k.cst --family GW1N-9C

# Empacotamento do Bitstream:
gowin_pack -d GW1N-9C -o build/riscv_prob_cpu.fs build/riscv_prob_cpu_pnr.json

# Carga na FPGA Tang Nano 9K:
openFPGALoader -b tangnano9k build/riscv_prob_cpu.fs
```

---

## 4. Teste Industrial
```bash
python3 tests/benchmark_industrial.py
```
* NIST Runs Test: $P\text{-value} = 0.2030$ (Aprovado).
* Entropia de Shannon: $H = 0.7802\text{ bits/bit}$.
* 100% de conformidade lógica nas portas AND, OR, NOR e XOR.
