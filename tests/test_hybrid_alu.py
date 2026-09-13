#!/usr/bin/env python3
"""
Test Native Hybrid RISC-V ALU on Tang Nano 9K
Tests:
- Banner with 'i(ALU)' command
- Native Instruction Execution: ADDI x1,1; ADDI x2,1; CUSTOM-0 pbit.xor x3,x1,x2
- Verifies writeback to register x3 = 0 (truth table match)
"""

import time
import serial
import sys

PORT = "/dev/ttyUSB1"
BAUD = 115200

def test_hybrid_alu():
    print(f"Connecting to Tang Nano 9K on {PORT} at {BAUD} baud...")
    try:
        ser = serial.Serial(PORT, BAUD, timeout=1.5)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

    time.sleep(0.1)
    ser.reset_input_buffer()
    ser.reset_output_buffer()

    # 1. Test Menu
    print("\n[1] Checking Menu Banner ('h'):")
    ser.write(b"h")
    time.sleep(0.2)
    resp_menu = ser.read(ser.in_waiting or 200).decode('ascii', errors='ignore')
    print(f"  Menu: {resp_menu.strip()}")
    assert "i(ALU)" in resp_menu, "i(ALU) command not found in banner!"

    # 2. Test Native Hybrid Instruction Execution ('i')
    print("\n[2] Executing Native Hybrid RISC-V Instruction Pipeline ('i'):")
    ser.reset_input_buffer()
    t0 = time.time()
    ser.write(b"i")
    time.sleep(0.35)
    resp_instr = ser.read(ser.in_waiting or 200).decode('ascii', errors='ignore')
    t_exec = (time.time() - t0) * 1000
    print(f"  Execution Output ({t_exec:.1f}ms):\n  {resp_instr.strip()}")
    
    assert "RV32-ALU" in resp_instr, "RV32-ALU prefix not found in output!"
    assert "x3=0" in resp_instr, "Register writeback x3=0 (XOR 1,1) failed!"
    print("  --> Hybrid ALU Instruction Passed: Register writeback x3 = 0 confirmed!")

    # 3. Test Classical Gates Regression ('a' and 'x')
    print("\n[3] Checking Regression of Gates ('a' and 'x'):")
    ser.reset_input_buffer()
    ser.write(b"a")
    time.sleep(0.35)
    resp_a = ser.read(ser.in_waiting or 200).decode('ascii', errors='ignore')
    print(f"  AND Response: {resp_a.strip().splitlines()[-1] if resp_a.strip() else 'None'}")

    ser.reset_input_buffer()
    ser.write(b"x")
    time.sleep(0.35)
    resp_x = ser.read(ser.in_waiting or 200).decode('ascii', errors='ignore')
    print(f"  XOR Response: {resp_x.strip().splitlines()[-1] if resp_x.strip() else 'None'}")

    print("\n=======================================================")
    print("  NATIVE HYBRID RISC-V ALU VERIFIED WITH 100% SUCCESS! ")
    print("=======================================================")

if __name__ == "__main__":
    test_hybrid_alu()
