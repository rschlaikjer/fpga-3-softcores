`default_nettype none

module timer_wb(
    // RCC
    input wire i_clk,
    input wire i_reset,
    // Trigger out signal
    output wire o_timer_trigger,
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

// Default prescaler value. Reloaded on reset.
parameter DEFAULT_PRESCALER = 32'hFFFF_FFFF;

// Prescaler value. Reloaded onto the downcounter on update.
reg [31:0] prescaler = DEFAULT_PRESCALER;

// Downcounter. Trigger output is latched high when this hits zero.
reg [31:0] downcounter = DEFAULT_PRESCALER;

// Register the output trigger signal
reg timer_trigger = 0;
assign o_timer_trigger = timer_trigger;

// Bit indices for the flags register
localparam
    wb_r_FLAGS__TRIGGER = 0;

// Flags register is just a collection of bits, in this case just the trigger
wire [31:0] flags;
assign flags[wb_r_FLAGS__TRIGGER] = timer_trigger;
assign flags[31:1] = 0;

// Wishbone register addresses
// Each register is actually 32 bits wide
localparam
    wb_r_PRESCALER  = 1'b0,
    wb_r_FLAGS      = 1'b1,
    wb_r_MAX        = 1'b1;

// Since the incoming wishbone address from the CPU increments by 4 bytes, we
// need to right shift it by 2 to get our actual register index
localparam reg_sel_bits = $clog2(wb_r_MAX + 1);
wire [reg_sel_bits-1:0] register_index = i_wb_adr[reg_sel_bits+1:2];

always @(posedge i_clk) begin
    if (i_reset) begin
        o_wb_ack <= 0;
        prescaler <= DEFAULT_PRESCALER;
        downcounter <= DEFAULT_PRESCALER;
        timer_trigger <= 1'b0;
    end else begin
        // Handle the downcounter
        if (downcounter > 0) begin
            downcounter <= downcounter - 1;
        end else begin
            downcounter <= prescaler;
            timer_trigger <= 1'b1;
        end

        // Wishbone interface logic
        o_wb_ack <= 1'b0;
        if (i_wb_cyc && i_wb_stb && !o_wb_ack) begin
            o_wb_ack <= 1'b1;

            // Register read
            case (register_index)
                wb_r_PRESCALER: o_wb_dat <= prescaler;
                wb_r_FLAGS:     o_wb_dat <= flags;
            endcase

            // Register write
            if (i_wb_we) begin
                case (register_index)
                    wb_r_PRESCALER: begin
                        // Load the new prescaler, also reset the downcounter
                        prescaler <= i_wb_dat;
                        downcounter <= i_wb_dat;
                    end
                    wb_r_FLAGS: begin
                        // If the trigger bit is written, clear the trig state
                        if (i_wb_dat[wb_r_FLAGS__TRIGGER])
                            timer_trigger <= 1'b0;
                    end
                endcase
            end
        end
    end
end

endmodule
