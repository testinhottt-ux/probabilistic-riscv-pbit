// ============================================================================
// Module: pbit_core
// Description: Thermodynamic Probabilistic Bit (p-bit) Core
// Implements: Langevin / Boltzmann Stochastic Activation Function
// P(out = 1) = 1 / (1 + exp(-beta * I_in))
// ============================================================================

`timescale 1ns / 1ps

module pbit_core #(
    parameter [31:0] SEED = 32'hDEADBEEF,
    parameter [31:0] POLY = 32'h80000057  // Primitive Galois polynomial
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire signed [15:0] inp_field,   // Fixed point 8.8
    input  wire [7:0]         beta,        // Inverse temperature (4.4 fixed point, 16 = 1.0)
    output reg         pbit_out,           // Instantaneous stochastic state (0 or 1)
    output wire [15:0] rand_noise,         // 16-bit pseudo-thermal noise output
    output wire [15:0] sigmoid_prob        // Theoretical sigmoid probability (0..65535)
);

    // 32-bit Galois Linear Feedback Shift Register (Entropy Generator)
    reg [31:0] lfsr;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr <= SEED;
        end else if (enable) begin
            if (lfsr[0])
                lfsr <= (lfsr >> 1) ^ POLY;
            else
                lfsr <= (lfsr >> 1);
        end
    end

    assign rand_noise = lfsr[15:0];

    // Scaled Input Field: x = inp_field * beta / 16
    wire signed [23:0] field_scaled = (inp_field * $signed({1'b0, beta})) >>> 4;

    // Piecewise Linear Sigmoid Approximation of 65536 / (1 + exp(-x))
    // x is 8.8 fixed-point (256 = 1.0)
    reg [15:0] sig_val;
    always @(*) begin
        if (field_scaled <= -1024) begin // x <= -4.0
            sig_val = 16'd1182;          // ~1.8%
        end else if (field_scaled <= -512) begin // -4.0 < x <= -2.0
            // Slope: (7820 - 1182)/512 = 13
            sig_val = 16'd1182 + (13 * (field_scaled + 1024));
        end else if (field_scaled <= -256) begin // -2.0 < x <= -1.0
            // Slope: (17621 - 7820)/256 = 38
            sig_val = 16'd7820 + (38 * (field_scaled + 512));
        end else if (field_scaled <= 0) begin // -1.0 < x <= 0
            // Slope: (32768 - 17621)/256 = 59
            sig_val = 16'd17621 + (59 * (field_scaled + 256));
        end else if (field_scaled <= 256) begin // 0 < x <= 1.0
            // Slope: 59
            sig_val = 16'd32768 + (59 * field_scaled);
        end else if (field_scaled <= 512) begin // 1.0 < x <= 2.0
            // Slope: 38
            sig_val = 16'd47915 + (38 * (field_scaled - 256));
        end else if (field_scaled <= 1024) begin // 2.0 < x <= 4.0
            // Slope: 13
            sig_val = 16'd57716 + (13 * (field_scaled - 512));
        end else begin // x > 4.0
            sig_val = 16'd64354;         // ~98.2%
        end
    end

    assign sigmoid_prob = sig_val;

    // Stochastic Sampling Comparator
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pbit_out <= 1'b0;
        end else if (enable) begin
            pbit_out <= (sig_val > lfsr[15:0]) ? 1'b1 : 1'b0;
        end
    end

endmodule
