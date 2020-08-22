`default_nettype none

module uart_tx (
    // Global clock
    input wire i_clk,
    input wire i_reset,
    // Physical UART output
    output wire o_uart_tx,
    // Data word to send
    input wire [DATA_WIDTH-1:0] i_data,
    // Input data valid
    input wire i_data_stb,
    // Status
    output wire o_busy,
    // Prescaler reload value
    // Must be externally registered
    input wire [15:0] i_baudrate_prescaler
);

    parameter DATA_WIDTH = 16;

    // Register some of our IO wires
    reg o_uart_tx_reg = 1;
    reg o_busy_reg = 0;
    assign o_uart_tx = o_uart_tx_reg;
    assign o_busy = o_busy_reg;

    // Internal data register
    reg [DATA_WIDTH:0] data_reg = 0;
    // Prescale register
    reg [15:0] prescale_reg = 0;
    // How many bits remain to be sent
    reg [$clog2(DATA_WIDTH+1):0] bit_cnt = 0;

    always @(posedge i_clk) begin
        if (i_reset) begin
            o_uart_tx_reg <= 1;
            prescale_reg <= 0;
            bit_cnt <= 0;
            o_busy_reg <= 0;
        end else begin
            // If we are prescaling, continue counting down to zero
            if (prescale_reg > 0) begin
                prescale_reg <= prescale_reg - 1;
            end else if (bit_cnt == 0) begin
                // If we are idle and the input data line is valid, load
                // the input data
                if (i_data_stb) begin
                    // Reset prescaler register
                    prescale_reg <= i_baudrate_prescaler;
                    // Load the bit count with the data width + stop bit
                    bit_cnt <= DATA_WIDTH+1;
                    // Data register is stop bit + input data
                    data_reg <= {1'b1, i_data};
                    // Start sending the start bit
                    o_uart_tx_reg <= 0;
                    // Transmit in progress
                    o_busy_reg <= 1;
                end else begin
                    // If the current bit count is zero (no data remaining to be
                    // sent) go back to being ready
                    o_busy_reg <= 0;
                end
            end else begin
                // Not in reset and bit count is non-zero
                if (bit_cnt > 1) begin
                    // Many bits remain.
                    // Decrement the number of bits to send
                    bit_cnt <= bit_cnt - 1;
                    // Reset our prescaler register
                    prescale_reg <= i_baudrate_prescaler;
                    // Right shift the data register, loading the lsb into our
                    // transmit data register
                    {data_reg, o_uart_tx_reg} <= {1'b0, data_reg};
                end else if (bit_cnt == 1) begin
                    // This is the final (stop) bit.
                    bit_cnt <= bit_cnt - 1;
                    prescale_reg <= i_baudrate_prescaler;
                    o_uart_tx_reg <= 1;
                end
            end
        end
    end

endmodule
