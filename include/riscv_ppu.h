/**
 * ============================================================================
 * File: riscv_ppu.h
 * Description: C Software Driver and Hardware Abstraction Layer (HAL)
 *              for the RISC-V Probabilistic Processing Unit (PPU)
 * Architecture: RV32I with Memory-Mapped Probabilistic Peripherals (0x80000000)
 * ============================================================================
 */

#ifndef RISCV_PPU_H
#define RISCV_PPU_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Base Address for Memory-Mapped PPU Registers
#define PPU_BASE_ADDR        0x80000000UL

// PPU Register Offsets
#define PPU_REG_CTRL         (*(volatile uint32_t *)(PPU_BASE_ADDR + 0x00))
#define PPU_REG_INPUT        (*(volatile uint32_t *)(PPU_BASE_ADDR + 0x04))
#define PPU_REG_DATA         (*(volatile uint32_t *)(PPU_BASE_ADDR + 0x08))
#define PPU_REG_STATUS       (*(volatile uint32_t *)(PPU_BASE_ADDR + 0x0C))
#define PPU_REG_SEED         (*(volatile uint32_t *)(PPU_BASE_ADDR + 0x10))

// PPU Operation Codes (PROB_CTRL)
#define PPU_OP_TRNG          0x00
#define PPU_OP_AND           0x01
#define PPU_OP_OR            0x02
#define PPU_OP_NOR           0x03
#define PPU_OP_XOR           0x04

// Status Register Bitmasks
#define PPU_STATUS_READY     (1U << 0)
#define PPU_STATUS_RESULT    (1U << 1)

// Input Register Bitmasks
#define PPU_INPUT_A          (1U << 0)
#define PPU_INPUT_B          (1U << 1)
#define PPU_INPUT_TRIGGER    (1U << 2)

/**
 * @brief Sets a new 32-bit entropy seed for the PPU Galois LFSR.
 */
static inline void ppu_set_seed(uint32_t seed) {
    PPU_REG_SEED = seed;
}

/**
 * @brief Reads a raw instantaneous thermodynamic stochastic bit from the p-bit core.
 * @return 0 or 1
 */
static inline uint8_t ppu_sample_bit(void) {
    return (uint8_t)(PPU_REG_DATA & 0x01);
}

/**
 * @brief Harvests a 32-bit cryptographically random word directly from the physical p-bit core.
 * @return 32-bit high-entropy integer
 */
static inline uint32_t ppu_get_trng32(void) {
    uint32_t val = 0;
    for (int i = 0; i < 32; i++) {
        val = (val << 1) | (PPU_REG_DATA & 0x01);
    }
    return val;
}

/**
 * @brief Executes a stochastic logic gate with 256-sample Monte Carlo majority voting.
 * @param op Operation code (PPU_OP_AND, PPU_OP_OR, PPU_OP_NOR, PPU_OP_XOR)
 * @param in_a Input operand A (0 or 1)
 * @param in_b Input operand B (0 or 1)
 * @return Deterministic majority output (0 or 1) with BER < 10^-16
 */
static inline uint8_t ppu_compute_gate(uint8_t op, uint8_t in_a, uint8_t in_b) {
    PPU_REG_CTRL = (uint32_t)op;
    
    uint32_t in_val = ((in_a & 1U) << 0) | ((in_b & 1U) << 1) | PPU_INPUT_TRIGGER;
    PPU_REG_INPUT = in_val;
    
    // Wait for the 256-cycle Monte Carlo integration window to complete
    while (!(PPU_REG_STATUS & PPU_STATUS_READY)) {
        // Yield or pipeline barrier
    }
    
    return (PPU_REG_STATUS & PPU_STATUS_RESULT) ? 1 : 0;
}

static inline uint8_t ppu_and(uint8_t a, uint8_t b) {
    return ppu_compute_gate(PPU_OP_AND, a, b);
}

static inline uint8_t ppu_or(uint8_t a, uint8_t b) {
    return ppu_compute_gate(PPU_OP_OR, a, b);
}

static inline uint8_t ppu_nor(uint8_t a, uint8_t b) {
    return ppu_compute_gate(PPU_OP_NOR, a, b);
}

static inline uint8_t ppu_xor(uint8_t a, uint8_t b) {
    return ppu_compute_gate(PPU_OP_XOR, a, b);
}

#ifdef __cplusplus
}
#endif

#endif // RISCV_PPU_H
