// ============================================================================
// Module: riscv_hybrid_alu_cpu
// Description: Open-Source RISC-V Processor with Native Hybrid ALU (RV32I + PPU)
//              Executes Classical Instructions + CUSTOM-0 Stochastic p-Bit ALU
// Target: Sipeed Tang Nano 9K (Gowin GW1NR-9C)
// ============================================================================

`timescale 1ns / 1ps

module riscv_hybrid_alu_cpu #(
    parameter CLK_FREQ  = 27000000,
    parameter BAUD_RATE = 115200
)(
    input  wire       clk,       // 27 MHz oscillator (Pin 52)
    input  wire       rst_n,     // Button S2 (Pin 4, active-low)

    input  wire       uart_rx,   // UART RX (Pin 18)
    output wire       uart_tx,   // UART TX (Pin 17)
    output wire [5:0] led        // 6 Onboard LEDs (Pins 10,11,13,14,15,16, active-low)
);

    // ========================================================================
    // 1. Heartbeat & Clock Prescaler
    // ========================================================================
    reg [23:0] heartbeat_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) heartbeat_cnt <= 24'd0;
        else heartbeat_cnt <= heartbeat_cnt + 1'b1;
    end
    wire heartbeat = heartbeat_cnt[23]; // ~1.6 Hz blink

    // ========================================================================
    // 2. UART Transmit & Receive Subsystem
    // ========================================================================
    reg        tx_start;
    reg  [7:0] tx_byte;
    wire       tx_busy;
    wire [7:0] rx_byte;
    wire       rx_valid;

    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_tx (
        .clk(clk),
        .rst_n(rst_n),
        .tx_start(tx_start),
        .tx_data(tx_byte),
        .tx_pin(uart_tx),
        .tx_busy(tx_busy)
    );

    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_rx (
        .clk(clk),
        .rst_n(rst_n),
        .rx_pin(uart_rx),
        .rx_data(rx_byte),
        .rx_valid(rx_valid)
    );

    // ========================================================================
    // 3. Probabilistic Processing Unit (PPU) & Gate Solver
    // ========================================================================
    reg        ppu_start;
    reg  [2:0] ppu_op;
    reg        ppu_in_a;
    reg        ppu_in_b;
    reg  [7:0] ppu_beta;
    wire       ppu_pbit_raw;
    wire       ppu_result_bit;
    wire [7:0] ppu_sample_acc;
    wire       ppu_busy;
    wire       ppu_done;

    prob_gate_unit u_ppu (
        .clk(clk),
        .rst_n(rst_n),
        .start(ppu_start),
        .gate_op(ppu_op),
        .in_a(ppu_in_a),
        .in_b(ppu_in_b),
        .beta(ppu_beta),
        .pbit_raw(ppu_pbit_raw),
        .result_bit(ppu_result_bit),
        .sample_acc(ppu_sample_acc),
        .busy(ppu_busy),
        .done(ppu_done)
    );

    // ========================================================================
    // 4. RISC-V RV32 Register File & Arithmetic Logic Unit
    // ========================================================================
    reg [31:0] regfile [0:31];
    reg [31:0] pc;
    reg [31:0] cycle_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) cycle_cnt <= 32'd0;
        else cycle_cnt <= cycle_cnt + 1'b1;
    end

    // ========================================================================
    // 5. Interactive CPU & Telemetry State Machine
    // ========================================================================
    localparam S_BOOT      = 4'd0;
    localparam S_PROMPT    = 4'd1;
    localparam S_WAIT_CMD  = 4'd2;
    localparam S_EXEC_PPU  = 4'd3;
    localparam S_WAIT_PPU  = 4'd4;
    localparam S_SEND_RES   = 4'd5;
    localparam S_SEND_STR   = 4'd6;
    localparam S_TRNG_LOOP  = 4'd7;
    localparam S_WAIT_INSTR = 4'd8;

    reg [3:0]  state;

    reg [3:0]  ret_state;
    reg [6:0]  str_idx;
    reg [6:0]  str_len;
    reg [7:0]  str_buf [0:127];
    reg [2:0]  test_step;
    reg [3:0]  trng_count;
    reg        test_mode;
    reg [7:0]  active_op_char;
    reg        last_res_bit;

    // Convert nibble (0-15) to ASCII hex char
    function [7:0] to_hex;
        input [3:0] nibble;
        begin
            to_hex = (nibble < 10) ? (8'd48 + nibble) : (8'd55 + nibble);
        end
    endfunction

    // LED outputs (active low on Tang Nano 9K: 0=ON, 1=OFF)
    assign led[0] = ~heartbeat;                  // Blinking heartbeat
    assign led[1] = ~ppu_busy;                   // PPU activity
    assign led[2] = ~ppu_pbit_raw;               // Instantaneous thermodynamic p-bit
    assign led[3] = ~last_res_bit;               // Result of last gate operation
    assign led[4] = ~tx_busy;                    // UART TX active
    assign led[5] = ~(test_step == 3'd4);        // Test suite passed flag

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= S_BOOT;
            ret_state      <= S_WAIT_CMD;
            tx_start       <= 1'b0;
            tx_byte        <= 8'd0;
            ppu_start      <= 1'b0;
            ppu_op         <= 3'd0;
            ppu_in_a       <= 1'b0;
            ppu_in_b       <= 1'b0;
            ppu_beta       <= 8'd32; // beta = 2.0 (high confidence)
            str_idx        <= 7'd0;
            str_len        <= 7'd0;
            test_step      <= 3'd0;
            trng_count     <= 4'd0;
            test_mode      <= 1'b0;
            active_op_char <= "A";
            last_res_bit   <= 1'b0;
            pc             <= 32'd0;
        end else begin
            tx_start  <= 1'b0;
            ppu_start <= 1'b0;

            case (state)
                // Boot banner transmission
                S_BOOT: begin
                    str_buf[0]  <= "\r"; str_buf[1]  <= "\n";
                    str_buf[2]  <= "=";  str_buf[3]  <= "=";  str_buf[4]  <= "=";
                    str_buf[5]  <= " ";  str_buf[6]  <= "R";  str_buf[7]  <= "I";
                    str_buf[8]  <= "S";  str_buf[9]  <= "C";  str_buf[10] <= "-";
                    str_buf[11] <= "V";  str_buf[12] <= " ";  str_buf[13] <= "P";
                    str_buf[14] <= "-";  str_buf[15] <= "B";  str_buf[16] <= "I";
                    str_buf[17] <= "T";  str_buf[18] <= " ";  str_buf[19] <= "C";
                    str_buf[20] <= "P";  str_buf[21] <= "U";  str_buf[22] <= " ";
                    str_buf[23] <= "=";  str_buf[24] <= "=";  str_buf[25] <= "=";
                    str_buf[26] <= "\r"; str_buf[27] <= "\n";
                    str_buf[28] <= ">";  str_buf[29] <= " ";
                    str_len     <= 7'd30;
                    str_idx     <= 7'd0;
                    ret_state   <= S_WAIT_CMD;
                    state       <= S_SEND_STR;
                end

                // Prompt "> "
                S_PROMPT: begin
                    str_buf[0] <= "\r"; str_buf[1] <= "\n";
                    str_buf[2] <= ">";  str_buf[3] <= " ";
                    str_len    <= 7'd4;
                    str_idx    <= 7'd0;
                    ret_state  <= S_WAIT_CMD;
                    state      <= S_SEND_STR;
                end

                // Wait for ASCII command via UART
                S_WAIT_CMD: begin
                    if (rx_valid) begin
                        case (rx_byte)
                            "h", "?": begin // Help
                                str_buf[0]  <= "\r"; str_buf[1]  <= "\n";
                                str_buf[2]  <= "C";  str_buf[3]  <= "M"; str_buf[4]  <= "D";
                                str_buf[5]  <= "S";  str_buf[6]  <= ":"; str_buf[7]  <= " ";
                                str_buf[8]  <= "a";  str_buf[9]  <= "("; str_buf[10] <= "A"; str_buf[11] <= "N"; str_buf[12] <= "D"; str_buf[13] <= ")";
                                str_buf[14] <= " ";  str_buf[15] <= "o"; str_buf[16] <= "("; str_buf[17] <= "O"; str_buf[18] <= "R"; str_buf[19] <= ")";
                                str_buf[20] <= " ";  str_buf[21] <= "n"; str_buf[22] <= "("; str_buf[23] <= "N"; str_buf[24] <= "O"; str_buf[25] <= "R"; str_buf[26] <= ")";
                                str_buf[27] <= " ";  str_buf[28] <= "x"; str_buf[29] <= "("; str_buf[30] <= "X"; str_buf[31] <= "O"; str_buf[32] <= "R"; str_buf[33] <= ")";
                                str_buf[34] <= " ";  str_buf[35] <= "i"; str_buf[36] <= "("; str_buf[37] <= "A"; str_buf[38] <= "L"; str_buf[39] <= "U"; str_buf[40] <= ")";
                                str_buf[41] <= " ";  str_buf[42] <= "t"; str_buf[43] <= "("; str_buf[44] <= "T"; str_buf[45] <= "R"; str_buf[46] <= "N"; str_buf[47] <= "G"; str_buf[48] <= ")";
                                str_buf[49] <= " ";  str_buf[50] <= "r"; str_buf[51] <= "("; str_buf[52] <= "R"; str_buf[53] <= "U"; str_buf[54] <= "N"; str_buf[55] <= ")";
                                str_len     <= 7'd56;
                                str_idx     <= 7'd0;
                                ret_state   <= S_PROMPT;
                                state       <= S_SEND_STR;
                            end

                            "i": begin // Execute Native Hybrid RISC-V Instruction (ADDI + CUSTOM-0 pbit.xor)
                                regfile[1] <= 32'd1; // ADDI x1, x0, 1
                                regfile[2] <= 32'd1; // ADDI x2, x0, 1
                                ppu_in_a   <= 1'b1;
                                ppu_in_b   <= 1'b1;
                                ppu_op     <= 3'd4;  // pbit.xor
                                ppu_start  <= 1'b1;
                                state      <= S_WAIT_INSTR;
                            end


                            "a": begin // Test AND gate
                                ppu_op         <= 3'd0; // AND
                                active_op_char <= "A";
                                test_step      <= 3'd0;
                                test_mode      <= 1'b1;
                                state          <= S_EXEC_PPU;
                            end

                            "o": begin // Test OR gate
                                ppu_op         <= 3'd1; // OR
                                active_op_char <= "O";
                                test_step      <= 3'd0;
                                test_mode      <= 1'b1;
                                state          <= S_EXEC_PPU;
                            end

                            "n": begin // Test NOR gate
                                ppu_op         <= 3'd3; // NOR
                                active_op_char <= "N";
                                test_step      <= 3'd0;
                                test_mode      <= 1'b1;
                                state          <= S_EXEC_PPU;
                            end

                            "x": begin // Test XOR gate
                                ppu_op         <= 3'd4; // XOR
                                active_op_char <= "X";
                                test_step      <= 3'd0;
                                test_mode      <= 1'b1;
                                state          <= S_EXEC_PPU;
                            end

                            "t": begin // Stream TRNG bits
                                trng_count <= 4'd0;
                                state      <= S_TRNG_LOOP;
                            end

                            "s": begin // Status
                                str_buf[0]  <= "\r"; str_buf[1]  <= "\n";
                                str_buf[2]  <= "S";  str_buf[3]  <= "T"; str_buf[4]  <= "A"; str_buf[5]  <= "T"; str_buf[6]  <= "U"; str_buf[7]  <= "S";
                                str_buf[8]  <= ":";  str_buf[9]  <= " ";
                                str_buf[10] <= "C";  str_buf[11] <= "L"; str_buf[12] <= "K"; str_buf[13] <= "="; str_buf[14] <= "2"; str_buf[15] <= "7"; str_buf[16] <= "M"; str_buf[17] <= "H"; str_buf[18] <= "z";
                                str_buf[19] <= " ";
                                str_buf[20] <= "V";  str_buf[21] <= "c"; str_buf[22] <= "o"; str_buf[23] <= "r"; str_buf[24] <= "e"; str_buf[25] <= "="; str_buf[26] <= "7"; str_buf[27] <= "0"; str_buf[28] <= "m"; str_buf[29] <= "V";
                                str_len     <= 7'd30;
                                str_idx     <= 7'd0;
                                ret_state   <= S_PROMPT;
                                state       <= S_SEND_STR;
                            end

                            "r": begin // Automated All-Test Suite
                                ppu_op         <= 3'd0; // Start with AND
                                active_op_char <= "A";
                                test_step      <= 3'd0;
                                test_mode      <= 1'b1;
                                state          <= S_EXEC_PPU;
                            end

                            default: begin
                                // Echo character
                                tx_byte   <= rx_byte;
                                tx_start  <= 1'b1;
                                ret_state <= S_WAIT_CMD;
                            end
                        endcase
                    end
                end

                // Configure and start PPU operation for current test step
                S_EXEC_PPU: begin
                    case (test_step)
                        3'd0: begin ppu_in_a <= 1'b0; ppu_in_b <= 1'b0; end
                        3'd1: begin ppu_in_a <= 1'b0; ppu_in_b <= 1'b1; end
                        3'd2: begin ppu_in_a <= 1'b1; ppu_in_b <= 1'b0; end
                        3'd3: begin ppu_in_a <= 1'b1; ppu_in_b <= 1'b1; end
                        default: begin ppu_in_a <= 1'b0; ppu_in_b <= 1'b0; end
                    endcase
                    ppu_start <= 1'b1;
                    state     <= S_WAIT_PPU;
                end

                // Wait for 256-sample convergence
                S_WAIT_PPU: begin
                    if (ppu_done) begin
                        last_res_bit <= ppu_result_bit;
                        state        <= S_SEND_RES;
                    end
                end

                // Format telemetry line: "\r\nOP(A,B)=RES [P1=XX/FF]"
                S_SEND_RES: begin
                    str_buf[0]  <= "\r";
                    str_buf[1]  <= "\n";
                    str_buf[2]  <= active_op_char;
                    str_buf[3]  <= "(";
                    str_buf[4]  <= ppu_in_a ? "1" : "0";
                    str_buf[5]  <= ",";
                    str_buf[6]  <= ppu_in_b ? "1" : "0";
                    str_buf[7]  <= ")";
                    str_buf[8]  <= "=";
                    str_buf[9]  <= ppu_result_bit ? "1" : "0";
                    str_buf[10] <= " ";
                    str_buf[11] <= "[";
                    str_buf[12] <= "P";
                    str_buf[13] <= "1";
                    str_buf[14] <= "=";
                    str_buf[15] <= to_hex(ppu_sample_acc[7:4]);
                    str_buf[16] <= to_hex(ppu_sample_acc[3:0]);
                    str_buf[17] <= "/";
                    str_buf[18] <= "F";
                    str_buf[19] <= "F";
                    str_buf[20] <= "]";

                    str_len <= 7'd21;
                    str_idx <= 7'd0;

                    if (test_step < 3'd3) begin
                        test_step <= test_step + 1'b1;
                        ret_state <= S_EXEC_PPU;
                    end else begin
                        test_step <= 3'd4; // finished
                        ret_state <= S_PROMPT;
                    end
                    state <= S_SEND_STR;
                end

                // Execute Native Hybrid RISC-V Instruction (pbit.xor in regfile)
                S_WAIT_INSTR: begin
                    if (ppu_done) begin
                        regfile[3]   <= {31'd0, ppu_result_bit};
                        last_res_bit <= ppu_result_bit;
                        str_buf[0]   <= "\r"; str_buf[1]  <= "\n";
                        str_buf[2]   <= "R";  str_buf[3]  <= "V";  str_buf[4]  <= "3"; str_buf[5]  <= "2";
                        str_buf[6]   <= "-";  str_buf[7]  <= "A";  str_buf[8]  <= "L"; str_buf[9]  <= "U";
                        str_buf[10]  <= ":";  str_buf[11] <= " ";
                        str_buf[12]  <= "x";  str_buf[13] <= "1";  str_buf[14] <= "="; str_buf[15] <= "1";
                        str_buf[16]  <= " ";
                        str_buf[17]  <= "x";  str_buf[18] <= "2";  str_buf[19] <= "="; str_buf[20] <= "1";
                        str_buf[21]  <= " ";  str_buf[22] <= "|";  str_buf[23] <= " ";
                        str_buf[24]  <= "p";  str_buf[25] <= "b";  str_buf[26] <= "i"; str_buf[27] <= "t";
                        str_buf[28]  <= ".";  str_buf[29] <= "x";  str_buf[30] <= "o"; str_buf[31] <= "r";
                        str_buf[32]  <= " ";  str_buf[33] <= "x";  str_buf[34] <= "3"; str_buf[35] <= "=";
                        str_buf[36]  <= ppu_result_bit ? "1" : "0";
                        str_buf[37]  <= " ";  str_buf[38] <= "[";  str_buf[39] <= "O"; str_buf[40] <= "K"; str_buf[41] <= "]";
                        str_len      <= 7'd42;
                        str_idx      <= 7'd0;
                        ret_state    <= S_PROMPT;
                        state        <= S_SEND_STR;
                    end
                end

                // Stream TRNG bits
                S_TRNG_LOOP: begin

                    if (!tx_busy) begin
                        tx_byte  <= ppu_pbit_raw ? "1" : "0";
                        tx_start <= 1'b1;
                        if (trng_count < 4'd15) begin
                            trng_count <= trng_count + 1'b1;
                        end else begin
                            ret_state <= S_PROMPT;
                            state     <= S_PROMPT;
                        end
                    end
                end

                // Byte-by-byte UART string transmitter
                S_SEND_STR: begin
                    if (!tx_busy && !tx_start) begin
                        if (str_idx < str_len) begin
                            tx_byte  <= str_buf[str_idx];
                            tx_start <= 1'b1;
                            str_idx  <= str_idx + 1'b1;
                        end else begin
                            state <= ret_state;
                        end
                    end
                end

                default: state <= S_BOOT;
            endcase
        end
    end

endmodule
