// ============================================================================
// Module: uart_tx
// Description: Full-duplex UART Transmitter (8N1)
// Parameterized for 27MHz clock and 115200 baud rate
// ============================================================================

`timescale 1ns / 1ps

module uart_tx #(
    parameter CLK_FREQ  = 27000000,
    parameter BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output reg        tx_pin,
    output wire       tx_busy
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE; // 234 for 27MHz/115200

    localparam STATE_IDLE  = 2'd0;
    localparam STATE_START = 2'd1;
    localparam STATE_DATA  = 2'd2;
    localparam STATE_STOP  = 2'd3;

    reg [1:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  data_buf;

    assign tx_busy = (state != STATE_IDLE);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= STATE_IDLE;
            tx_pin   <= 1'b1;
            clk_cnt  <= 16'd0;
            bit_idx  <= 3'd0;
            data_buf <= 8'd0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    tx_pin  <= 1'b1;
                    clk_cnt <= 16'd0;
                    bit_idx <= 3'd0;
                    if (tx_start) begin
                        data_buf <= tx_data;
                        state    <= STATE_START;
                    end
                end

                STATE_START: begin
                    tx_pin <= 1'b0; // Start bit
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end else begin
                        clk_cnt <= 16'd0;
                        state   <= STATE_DATA;
                    end
                end

                STATE_DATA: begin
                    tx_pin <= data_buf[bit_idx];
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end else begin
                        clk_cnt <= 16'd0;
                        if (bit_idx < 3'd7) begin
                            bit_idx <= bit_idx + 1'b1;
                        end else begin
                            bit_idx <= 3'd0;
                            state   <= STATE_STOP;
                        end
                    end
                end

                STATE_STOP: begin
                    tx_pin <= 1'b1; // Stop bit
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end else begin
                        clk_cnt <= 16'd0;
                        state   <= STATE_IDLE;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
