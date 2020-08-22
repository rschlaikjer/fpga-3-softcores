module uart_wb(
    // RCC
    input wire i_clk,
    input wire i_reset,
    // Physical signals
    input wire i_uart_rx,
    output wire o_uart_tx,
    // Wishbone
    input  wire [31:0] i_wb_adr,
    input  wire [31:0] i_wb_dat,
    input  wire  [3:0] i_wb_sel,
    input  wire        i_wb_we,
    input  wire        i_wb_cyc,
    input  wire        i_wb_stb,
    output reg  [31:0] o_wb_dat,
    output reg         o_wb_ack
);

parameter TX_BUFSIZE = 8;
parameter RX_BUFSIZE = 8;
parameter DATA_WIDTH = 16;

reg [15:0] baudrate_prescaler = 0;

// Transmit block
wire [DATA_WIDTH-1:0] rx_data;
wire                  rx_stb;
uart_rx #(
    .DATA_WIDTH(DATA_WIDTH)
) rx0 (
    .i_clk(i_clk),
    .i_reset(i_reset),
    .i_uart_rx(i_uart_rx),
    .o_data(rx_data),
    .o_data_stb(rx_stb),
    .i_baudrate_prescaler(baudrate_prescaler)
);

// Receive block
wire [DATA_WIDTH-1:0] tx_data;
wire                  tx_stb;
wire                  tx_busy;
uart_tx #(
    .DATA_WIDTH(DATA_WIDTH)
) tx0 (
    .i_clk(i_clk),
    .i_reset(i_reset),
    .o_uart_tx(o_uart_tx),
    .i_data(tx_data),
    .i_data_stb(tx_stb),
    .o_busy(tx_busy),
    .i_baudrate_prescaler(baudrate_prescaler)
);

// RX FIFO
wire [DATA_WIDTH-1:0]         rx_fifo_r_data;
reg                           rx_fifo_r_stb;
wire                          rx_fifo_full;
wire                          rx_fifo_empty;
wire [$clog2(RX_BUFSIZE)-1:0] rx_fifo_item_count;
wire [$clog2(RX_BUFSIZE)-1:0] rx_fifo_free_size;
fifo #(
    .DATA_WIDTH(DATA_WIDTH),
    .MAX_ENTRIES(RX_BUFSIZE)
) rx0_fifo (
    .i_reset(i_reset),
    .i_clk(i_clk),
    // Write interface: direct from UART
    .i_w_data(rx_data),
    .i_w_data_stb(rx_stb),
    // Read interface: to wishbone
    .o_r_data(rx_fifo_r_data),
    .i_r_data_stb(rx_fifo_r_stb),
    .o_full(rx_fifo_full),
    .o_empty(rx_fifo_empty),
    .o_item_count(rx_fifo_item_count),
    .o_free_size(rx_fifo_free_size)
);

// TX FIFO
reg  [DATA_WIDTH-1:0]         tx_fifo_w_data;
reg                           tx_fifo_w_stb;
wire                          tx_fifo_full;
wire                          tx_fifo_empty;
wire [$clog2(TX_BUFSIZE)-1:0] tx_fifo_item_count;
wire [$clog2(TX_BUFSIZE)-1:0] tx_fifo_free_size;
fifo #(
    .DATA_WIDTH(DATA_WIDTH),
    .MAX_ENTRIES(TX_BUFSIZE)
) tx0_fifo (
    .i_reset(i_reset),
    .i_clk(i_clk),
    // Write interface: from wishbone
    .i_w_data(tx_fifo_w_data),
    .i_w_data_stb(tx_fifo_w_stb),
    // Read interface: to uart
    .o_r_data(tx_data),
    .i_r_data_stb(tx_stb),
    .o_full(tx_fifo_full),
    .o_empty(tx_fifo_empty),
    .o_item_count(tx_fifo_item_count),
    .o_free_size(tx_fifo_free_size)
);

// Strobe the uart TX whenever the uart isn't busy and the fifo isn't empty
assign tx_stb = !tx_busy && !tx_fifo_empty;

// Wishbone logic
localparam
    // General
    wb_r_conf_prescaler     = 6'h00,
    // TX
    wb_r_tx_flags           = 6'h10,
    wb_r_tx_item_count      = 6'h11,
    wb_r_tx_free_size       = 6'h12,
    wb_r_tx_write           = 6'h13,
    // RX
    wb_r_rx_flags           = 6'h20,
    wb_r_rx_item_count      = 6'h21,
    wb_r_rx_free_size       = 6'h22,
    wb_r_rx_read            = 6'h23,
    //
    wb_r_max = 6'h23;


wire [31:0] tx_flags = {30'd0, tx_fifo_full, tx_fifo_empty};
wire [31:0] rx_flags = {30'd0, rx_fifo_full, rx_fifo_empty};

`define EXTEND(value) {{32-$bits(value){1'b0}}, value}

// Adjust register offset for 32 bit words
localparam addr_bits = $clog2(wb_r_max+1);
wire [addr_bits-1:0] register_index = i_wb_adr[addr_bits+1:2];

always @(posedge i_clk) begin
    if (i_reset) begin
        o_wb_ack <= 1'b0;
    end else begin

        // Clear strobes
        o_wb_ack <= 1'b0;
        rx_fifo_r_stb <= 1'b0;
        tx_fifo_w_stb <= 1'b0;

        if (i_wb_cyc && i_wb_stb && !o_wb_ack) begin
            // Reads
            case (register_index)

                wb_r_conf_prescaler:    o_wb_dat <= `EXTEND(baudrate_prescaler);

                wb_r_tx_flags:          o_wb_dat <= tx_flags;
                wb_r_tx_item_count:     o_wb_dat <= `EXTEND(tx_fifo_item_count);
                wb_r_tx_free_size:      o_wb_dat <= `EXTEND(tx_fifo_free_size);

                wb_r_rx_read: begin
                    o_wb_dat <= `EXTEND(rx_fifo_r_data);
                    rx_fifo_r_stb <= 1'b1;
                end
                wb_r_rx_flags:          o_wb_dat <= rx_flags;
                wb_r_rx_item_count:     o_wb_dat <= `EXTEND(rx_fifo_item_count);
                wb_r_rx_free_size:      o_wb_dat <= `EXTEND(rx_fifo_free_size);

                default: /* Bad register */ o_wb_dat <= 32'hDEADBEEF;
            endcase

            // Writes
            if (i_wb_we) begin
            case (register_index)

                wb_r_conf_prescaler: baudrate_prescaler <= i_wb_dat[$bits(baudrate_prescaler)-1:0];

                wb_r_tx_write: begin
                    tx_fifo_w_data <= i_wb_dat[DATA_WIDTH-1:0];
                    tx_fifo_w_stb <= 1'b1;
                end

                default: /* Bad register */ ;
            endcase
            end

            o_wb_ack <= 1'b1;
        end

    end
end

endmodule
