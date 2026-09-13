// ============================================================================
// Module: prob_gate_unit
// Description: Probabilistic Logic Gate Unit (AND, OR, NAND, NOR, XOR, XNOR)
// Built using coupled thermodynamic p-bits with Langevin/Boltzmann dynamics
// ============================================================================

`timescale 1ns / 1ps

module prob_gate_unit (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [2:0]  gate_op,    // 0: AND, 1: OR, 2: NAND, 3: NOR, 4: XOR, 5: XNOR, 6: TRNG
    input  wire        in_a,
    input  wire        in_b,
    input  wire [7:0]  beta,       // Inverse temperature parameter (gain)
    output wire        pbit_raw,   // Instantaneous stochastic bit
    output reg         result_bit, // Majority-vote result after sampling window
    output reg  [7:0]  sample_acc, // Accumulator of 1s over 256 cycles (P(1) * 256)
    output reg         busy,
    output reg         done
);

    // Operation codes
    localparam OP_AND  = 3'd0;
    localparam OP_OR   = 3'd1;
    localparam OP_NAND = 3'd2;
    localparam OP_NOR  = 3'd3;
    localparam OP_XOR  = 3'd4;
    localparam OP_XNOR = 3'd5;
    localparam OP_TRNG = 3'd6;

    // Fixed-point scaling (8.8 format): 1.0 = 256, 2.0 = 512, 3.0 = 768, 4.0 = 1024
    wire signed [15:0] term_a = in_a ? 16'sd512 : 16'sd0;
    wire signed [15:0] term_b = in_b ? 16'sd512 : 16'sd0;

    // Auxiliary p-bit for XOR hidden layer (computes stochastic AND)
    wire signed [15:0] h_field = -16'sd768 + term_a + term_b;
    wire h_pbit;
    wire [15:0] h_noise;
    wire [15:0] h_sig;

    pbit_core #(
        .SEED(32'hA5A5C3C3),
        .POLY(32'h80000061)
    ) pbit_hidden (
        .clk(clk),
        .rst_n(rst_n),
        .enable(1'b1),
        .inp_field(h_field),
        .beta(beta),
        .pbit_out(h_pbit),
        .rand_noise(h_noise),
        .sigmoid_prob(h_sig)
    );

    // Primary p-bit input field selector based on gate_op
    reg signed [15:0] main_field;
    always @(*) begin
        case (gate_op)
            OP_AND:  main_field = -16'sd768 + term_a + term_b;
            OP_OR:   main_field = -16'sd256 + term_a + term_b;
            OP_NAND: main_field =  16'sd768 - term_a - term_b;
            OP_NOR:  main_field =  16'sd256 - term_a - term_b;
            OP_XOR:  main_field = -16'sd256 + term_a + term_b - (h_pbit ? 16'sd1024 : 16'sd0);
            OP_XNOR: main_field =  16'sd256 - term_a - term_b + (h_pbit ? 16'sd1024 : 16'sd0);
            OP_TRNG: main_field =  16'sd0; // Zero bias: 50/50 pure thermodynamic entropy
            default: main_field =  16'sd0;
        endcase
    end

    // Main output p-bit
    wire main_pbit;
    wire [15:0] main_noise;
    wire [15:0] main_sig;

    pbit_core #(
        .SEED(32'h13579BDF),
        .POLY(32'h80000057)
    ) pbit_output (
        .clk(clk),
        .rst_n(rst_n),
        .enable(1'b1),
        .inp_field(main_field),
        .beta(beta),
        .pbit_out(main_pbit),
        .rand_noise(main_noise),
        .sigmoid_prob(main_sig)
    );

    assign pbit_raw = main_pbit;

    // Sampling state machine (accumulates 256 samples to determine convergence and P(1))
    reg [7:0] sample_counter;
    reg [8:0] acc_reg; // up to 256

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_counter <= 8'd0;
            acc_reg        <= 9'd0;
            sample_acc     <= 8'd0;
            result_bit     <= 1'b0;
            busy           <= 1'b0;
            done           <= 1'b0;
        end else begin
            if (start && !busy) begin
                busy           <= 1'b1;
                done           <= 1'b0;
                sample_counter <= 8'd0;
                acc_reg        <= 9'd0;
            end else if (busy) begin
                acc_reg <= acc_reg + main_pbit;
                if (sample_counter == 8'd255) begin
                    busy           <= 1'b0;
                    done           <= 1'b1;
                    sample_acc     <= acc_reg[7:0];
                    result_bit     <= (acc_reg >= 9'd128) ? 1'b1 : 1'b0;
                end else begin
                    sample_counter <= sample_counter + 1'b1;
                end
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule
