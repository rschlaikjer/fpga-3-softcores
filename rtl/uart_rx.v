`default_nettype none

module uart_rx (
    // Global clock
    input wire i_clk,
    input wire i_reset,
    // Physical UART input
    input wire i_uart_rx,
    // Output data
    output wire [DATA_WIDTH-1:0] o_data,
    // Output data valid strobe
    output wire o_data_stb,
    // Prescaler reload value
    // Must be externally registered
    input wire [15:0] i_baudrate_prescaler
);

    parameter DATA_WIDTH = 16;

    // Delay latches for metastability
    reg [2:0] r_uart_rx;
    wire uart_rx = r_uart_rx[2];
    always @(posedge i_clk) begin
        r_uart_rx <= {r_uart_rx[1], r_uart_rx[0], i_uart_rx};
    end

    // Data register
    reg [DATA_WIDTH-1:0] r_data = 0;
    assign o_data = r_data;
    reg r_data_valid = 0;
    assign o_data_stb = r_data_valid;

    // Received bits counter
    reg [$clog2(DATA_WIDTH):0] r_rx_bit_count = 0;

    // State
    reg [1:0] state = s_IDLE;
    localparam
        s_IDLE = 0,
        s_RECEIVE = 1,
        s_STOP = 2;

    // Baudrate clock generator
    // When the logic is in s_IDLE, the prescaler counter is loaded with
    // 1.5 times the normal period so that we sample nicely in the middle
    // of each bit
    reg [15:0] r_prescaler_counter= 0;
    reg r_baud_clock;
    always @(posedge i_clk) begin
        if (i_reset) begin
            r_prescaler_counter <= i_baudrate_prescaler;
            r_baud_clock <= 0;
        end else begin
            if (state == s_IDLE) begin
                // Keep prescaler loaded with 1.5x the normal value for offset
                r_prescaler_counter <= (i_baudrate_prescaler + (i_baudrate_prescaler >> 1));
                r_baud_clock <= 0;
            end else begin
                if (r_prescaler_counter > 0) begin
                    r_prescaler_counter <= r_prescaler_counter - 1;
                    r_baud_clock <= 0;
                end else begin
                    r_baud_clock <= ~r_baud_clock;
                    r_prescaler_counter <= i_baudrate_prescaler;
                    r_baud_clock <= 1;
                end
            end
        end
    end

    // Receive logic
    always @(posedge i_clk) begin
        if (i_reset) begin
            r_data <= 0;
            r_data_valid <= 0;
            r_rx_bit_count <= 0;
            state <= s_IDLE;
        end else begin
            case (state)

            s_IDLE: begin
                // Wait for the uart data to go low for the start bit
                if (uart_rx == 1'b0) begin
                    r_rx_bit_count <= 0;
                    state <= s_RECEIVE;
                end
                // Clear DV line
                r_data_valid <= 1'b0;
            end

            s_RECEIVE: begin
                // If the rx baud clock pulsed, sample the RX data
                if (r_baud_clock) begin
                    // Sample the input data
                    r_data <= {uart_rx, r_data[DATA_WIDTH-1:1]};
                    // Increment the rx bit count
                    r_rx_bit_count <= r_rx_bit_count + 1;
                end

                // If we have received all the bits, strobe output and idle to
                // handle the stop bit
                if (r_rx_bit_count == DATA_WIDTH[$clog2(DATA_WIDTH):0]) begin
                    r_data_valid <= 1'b1;
                    state <= s_STOP;
                end
            end

            s_STOP: begin
                // Simply wait for one more clock of the baud clock so that
                // we do not accidentally re-trigger as the transmitter
                // goes to the stop bit
                if (r_baud_clock) begin
                    state <= s_IDLE;
                end
                r_data_valid <= 1'b0;
            end


            default: begin
                state <= s_IDLE;
            end

            endcase
        end
    end

endmodule
