`default_nettype none

module wb_ram(
    // RCC
    input wire i_clk,
    input wire i_reset,
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

// Number of 32-bit words to store
parameter SIZE = 512;

// Data storage
reg [31:0] data [SIZE];

// If we have been given an initial file parameter, load that
parameter INITIAL_HEX = "";
initial begin
    /* verilator lint_off WIDTH */
    if (INITIAL_HEX != "")
        $readmemh(INITIAL_HEX, data);
    /* verilator lint_on WIDTH */
end

// Each data entry is 32 bits wide, so right shift the input address
localparam addr_width = $clog2(SIZE);
wire [addr_width-1:0] data_addr = i_wb_adr[addr_width+1:2];

integer i;
always @(posedge i_clk) begin
    if (i_reset) begin
        o_wb_ack <= 1'b0;
    end else begin
        o_wb_ack <= 1'b0;

        if (i_wb_cyc & i_wb_stb & ~o_wb_ack) begin
            // Always ack
            o_wb_ack <= 1'b1;

            // Reads
            o_wb_dat <= data[data_addr];

            // Writes
            if (i_wb_we) begin
                for (i = 0; i < 4; i++) begin
                    if (i_wb_sel[i])
                        data[data_addr][i*8 +: 8] <= i_wb_dat[i*8 +: 8];
                end
            end
        end
    end
end

endmodule
