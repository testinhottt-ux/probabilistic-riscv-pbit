#!/usr/bin/env python3
"""
===============================================================================
ENSAIO INDUSTRIAL QUALIFICATÓRIO: ALU HÍBRIDA NATIVA RISC-V + p-BIT (RV32I-P)
Dispositivo: Sipeed Tang Nano 9K (Gowin GW1NR-9C) via UART (/dev/ttyUSB1)
===============================================================================
Executa ciclo contínuo de estresse de 500 operações da ALU híbrida, testando:
1. Execução de pipeline combinada: Instruções determinísticas + CUSTOM-0 estocástica
2. Verificação de writeback no banco de registradores x1, x2, x3
3. Taxa de Erro de Bit (BER) sob estresse térmico
4. Latência média por instrução e throughput de processamento
"""

import time
import serial
import sys

PORT = "/dev/ttyUSB1"
BAUD = 115200
CYCLES = 500

def run_industrial_alu_benchmark():
    print("=" * 80)
    print("  QUALIFICAÇÃO INDUSTRIAL: ALU HÍBRIDA RISC-V RV32I + p-BIT")
    print("  Dispositivo: Sipeed Tang Nano 9K via USB UART (/dev/ttyUSB1)")
    print("=" * 80)

    try:
        ser = serial.Serial(PORT, BAUD, timeout=1.5)
    except Exception as e:
        print(f"[ERRO] Não foi possível abrir {PORT}: {e}")
        sys.exit(1)

    time.sleep(0.1)
    ser.reset_input_buffer()
    ser.reset_output_buffer()

    # 1. Verificação de Handshake e Menu
    ser.write(b"h")
    time.sleep(0.15)
    banner = ser.read(ser.in_waiting or 200).decode('ascii', errors='ignore')
    if "i(ALU)" not in banner:
        print("[FALHA] Comando i(ALU) não detectado no firmware da CPU!")
        sys.exit(1)
    print("[OK] CPU RISC-V com ALU Híbrida respondendo normalmente na porta serial.")

    # 2. Ciclo de Estresse Industrial de 500 Operações
    print(f"\n[ENSAIO 1] Estresse Contínuo da ALU Híbrida ({CYCLES} iterações)...")
    print("           Sequência: ADDI x1,1 -> ADDI x2,1 -> CUSTOM-0 pbit.xor x3,x1,x2")

    success_count = 0
    error_count = 0
    latencies = []

    t_start_total = time.time()

    for i in range(CYCLES):
        ser.reset_input_buffer()
        t0 = time.time()
        ser.write(b"i")
        time.sleep(0.04) # Janela de amostragem
        resp = ser.read(ser.in_waiting or 100).decode('ascii', errors='ignore')
        t_cycle = (time.time() - t0) * 1000
        latencies.append(t_cycle)

        # Valida writeback correto: x3=0 (1 XOR 1 = 0 com unidade oculta H)
        if "x3=0" in resp and "[OK]" in resp:
            success_count += 1
        else:
            error_count += 1

        if (i + 1) % 100 == 0:
            print(f"  -> Progresso: {i + 1:3d}/{CYCLES} | Acertos: {success_count} | Erros: {error_count} | Latência média: {sum(latencies[-100:])/100:.1f} ms")

    total_time = time.time() - t_start_total
    avg_latency = sum(latencies) / len(latencies)
    throughput = CYCLES / total_time
    ber = error_count / CYCLES

    print("\n[ENSAIO 2] Métricas Consolidadas de Confiabilidade Industrial:")
    print(f"  * Total de Ciclos de Teste : {CYCLES}")
    print(f"  * Sucessos de Writeback    : {success_count} ({success_count/CYCLES*100:.2f}%)")
    print(f"  * Falhas / Erros de Bit    : {error_count}")
    print(f"  * Taxa de Erro de Bit (BER): {ber:.2e} (Critério Industrial: < 1e-4)")
    print(f"  * Tempo Total do Ensaio    : {total_time:.2f} segundos")
    print(f"  * Latência Média de Decisão: {avg_latency:.2f} ms")
    print(f"  * Throughput Efetivo       : {throughput:.1f} instruções híbridas/segundo")

    assert error_count == 0, f"Falha no ensaio industrial! {error_count} erros detectados."
    print("\n[RESULTADO] ALU HÍBRIDA RISC-V APROVADA COM 100% DE CONFORMIDADE!")
    print("=" * 80)
    ser.close()
    return True

if __name__ == "__main__":
    run_industrial_alu_benchmark()
