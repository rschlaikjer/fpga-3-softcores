`default_nettype none

module fifo(
    // RCC
    input wire i_reset,
    input wire i_clk,
    // Write
    input [DATA_WIDTH-1:0] i_w_data,
    input wire i_w_data_stb,
    // Read
    output wire [DATA_WIDTH-1:0] o_r_data,
    input wire i_r_data_stb,
    // Status
    output wire o_full,
    output wire o_empty,
    output wire [$clog2(MAX_ENTRIES)-1:0] o_item_count,
    output wire [$clog2(MAX_ENTRIES)-1:0] o_free_size
);

// Width of FIFO entries
parameter DATA_WIDTH = 16;
// Element count for backing data array.
// Note that this implementation can only actually hold MAX_ENTRIES - 1 entries
parameter MAX_ENTRIES = 8;

// Read/write pointers
reg [$clog2(MAX_ENTRIES)-1:0] write_idx = 0;
reg [$clog2(MAX_ENTRIES)-1:0] read_idx  = 0;

// Data storage
reg [DATA_WIDTH-1:0] data [MAX_ENTRIES-1:0];

// Empty if read/write are same index
wire [$clog2(MAX_ENTRIES)-1:0] read_plus_1 = read_idx + 1;
reg r_empty = 1'b1;
assign o_empty = r_empty;

// Full if write + 1 == read
wire [$clog2(MAX_ENTRIES)-1:0] write_plus_2 = write_idx + 2;
reg r_full = 1'b0;
assign o_full = r_full;

// Number of items in FIFO
reg [$clog2(MAX_ENTRIES)-1:0] r_item_count = 0;
assign o_item_count = r_item_count;
// Free size is max size - item_count - 1
wire [$clog2(MAX_ENTRIES+1)-1:0] free_size = (MAX_ENTRIES-1) - r_item_count;
assign o_free_size = free_size[$clog2(MAX_ENTRIES)-1:0];

// Buffer for read data from block ram
// Need to always read this for it to interpret the read clock domain correctly
reg [DATA_WIDTH-1:0] read_idx_data;

// If a write occurs to an empty fifo, the r_empty signal will go low
// immediately, but the output value will not change until the cycle after.
// To get around this, check for this case and display the input directly on
// the output when it happens
reg is_write_on_empty;
always @(posedge i_clk)
    is_write_on_empty <= (write_idx == read_idx && i_w_data_stb);
assign o_r_data = is_write_on_empty ? i_w_data : read_idx_data;

// Data
always @(posedge i_clk) begin
    if (i_reset) begin
        write_idx <= 0;
        read_idx <= 0;
    end else begin
        // Read can always load the data at the read index into the output reg
        read_idx_data <= data[read_idx];

        // Special case concurrent write + read - this works even if we are full
        // since both pointers will move
        if (!r_empty && i_w_data_stb && i_r_data_stb) begin
            data[write_idx] <= i_w_data;
            write_idx <= write_idx + 1;
            read_idx <= read_idx + 1;
        end else begin
            // Are we being written?
            if (i_w_data_stb && !r_full) begin
                // Set write enable on RAM
                data[write_idx] <= i_w_data;
                write_idx <= write_idx + 1;
            end

            // Are we being read?
            if (i_r_data_stb && !r_empty) begin
                read_idx <= read_idx + 1;
            end
        end

    end
end

// Size and flags
always @(posedge i_clk) begin
    if (i_reset) begin
        r_item_count <= 0;
        r_full <= 0;
        r_empty <= 1;
    end else begin
        casez ({i_w_data_stb, i_r_data_stb, r_empty, r_full})
            4'b010?: begin
                // Read while non-empty
                r_item_count <= r_item_count - 1;
                r_empty <= read_plus_1 == write_idx;
                r_full <= 0; // Can't be full if we just read something
            end
            4'b10?0: begin
                // Write while non-full
                r_item_count <= r_item_count + 1;
                r_full <= write_plus_2 == read_idx;
                r_empty <= 0; // Can't be empty if we just wrote something
            end
            default: begin /* anything else doesn't affect */ end
        endcase
    end
end

endmodule
