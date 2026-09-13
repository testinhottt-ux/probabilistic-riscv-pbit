#!/usr/bin/env python3
"""
Automated Hardware Verification Suite for Probabilistic RISC-V CPU on Tang Nano 9K
Communicates with the FPGA over USB UART (/dev/ttyUSB1) at 115200 baud.
Tests:
- Banner & System ID
- Probabilistic AND Gate
- Probabilistic OR Gate
- Probabilistic NOR Gate
- Probabilistic XOR Gate (with hidden p-bit unit)
- Thermodynamic True Random Bit Stream (TRNG)
- Complete Verification Benchmark
"""

import time
import sys
import serial

PORT = "/dev/ttyUSB1"
BAUD = 115200

def test_fpga():
    print(f"Connecting to Tang Nano 9K on {PORT} at {BAUD} baud...")
    try:
        ser = serial.Serial(PORT, BAUD, timeout=1.0)
    except Exception as e:
        print(f"Error opening {PORT}: {e}")
        sys.exit(1)

    time.sleep(0.1)
    ser.reset_input_buffer()
    ser.reset_output_buffer()

    # Send '?' to read banner
    print("\n--- 1. Testing System Banner & ID ('h') ---")
    t0 = time.time()
    ser.write(b"h")
    time.sleep(0.15)
    resp = ser.read(ser.in_waiting or 100).decode('ascii', errors='ignore')
    t_banner = (time.time() - t0) * 1000
    print(f"Response ({t_banner:.1f}ms): {resp.strip()}")

    # Test AND Gate
    print("\n--- 2. Testing Probabilistic AND Gate ('a') ---")
    ser.reset_input_buffer()
    t0 = time.time()
    ser.write(b"a")
    time.sleep(0.3)
    resp_and = ser.read(ser.in_waiting or 200).decode('ascii', errors='ignore')
    t_and = (time.time() - t0) * 1000
    print(f"AND Results ({t_and:.1f}ms):\n{resp_and.strip()}")

    # Test OR Gate
    print("\n--- 3. Testing Probabilistic OR Gate ('o') ---")
    ser.reset_input_buffer()
    t0 = time.time()
    ser.write(b"o")
    time.sleep(0.3)
    resp_or = ser.read(ser.in_waiting or 200).decode('ascii', errors='ignore')
    t_or = (time.time() - t0) * 1000
    print(f"OR Results ({t_or:.1f}ms):\n{resp_or.strip()}")

    # Test NOR Gate
    print("\n--- 4. Testing Probabilistic NOR Gate ('n') ---")
    ser.reset_input_buffer()
    t0 = time.time()
    ser.write(b"n")
    time.sleep(0.3)
    resp_nor = ser.read(ser.in_waiting or 200).decode('ascii', errors='ignore')
    t_nor = (time.time() - t0) * 1000
    print(f"NOR Results ({t_nor:.1f}ms):\n{resp_nor.strip()}")

    # Test XOR Gate
    print("\n--- 5. Testing Probabilistic XOR Gate ('x') ---")
    ser.reset_input_buffer()
    t0 = time.time()
    ser.write(b"x")
    time.sleep(0.3)
    resp_xor = ser.read(ser.in_waiting or 200).decode('ascii', errors='ignore')
    t_xor = (time.time() - t0) * 1000
    print(f"XOR Results ({t_xor:.1f}ms):\n{resp_xor.strip()}")

    # Test TRNG Stream
    print("\n--- 6. Testing Thermodynamic TRNG Stream ('t') ---")
    ser.reset_input_buffer()
    t0 = time.time()
    ser.write(b"t")
    time.sleep(0.2)
    resp_trng = ser.read(ser.in_waiting or 100).decode('ascii', errors='ignore')
    t_trng = (time.time() - t0) * 1000
    print(f"TRNG Stream ({t_trng:.1f}ms):\n{resp_trng.strip()}")

    # Test Status
    print("\n--- 7. Testing CPU Status ('s') ---")
    ser.reset_input_buffer()
    t0 = time.time()
    ser.write(b"s")
    time.sleep(0.15)
    resp_stat = ser.read(ser.in_waiting or 100).decode('ascii', errors='ignore')
    t_stat = (time.time() - t0) * 1000
    print(f"CPU Status ({t_stat:.1f}ms):\n{resp_stat.strip()}")

    ser.close()
    print("\n=== HARDWARE VERIFICATION COMPLETE ===")

if __name__ == "__main__":
    test_fpga()
