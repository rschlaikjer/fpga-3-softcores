`default_nettype none

module rgb_led_wb(
    // RCC
    input wire i_clk,
    input wire i_reset,
    // Output BGR signal
    output reg [2:0] o_led_bgr,
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

// Wishbone register addresses
localparam
    wb_r_PWM_PRESCALER  = 1'b0,
    wb_r_BGR_DATA       = 1'b1,
    wb_r_MAX            = 1'b1;

// PWM prescaler register
reg [31:0] pwm_prescaler;
reg [31:0] pwm_downcounter;
reg [7:0]  pwm_compare;

// BGR output compare registers
reg [7:0] ocr_b;
reg [7:0] ocr_g;
reg [7:0] ocr_r;

// PWM generation
always @(posedge i_clk) begin
    // Prescaled counter for the pwm compare register
    if (pwm_downcounter > 0) begin
        pwm_downcounter <= pwm_downcounter - 1;
    end else begin
        pwm_downcounter <= pwm_prescaler;
        pwm_compare <= pwm_compare + 1;
    end

    // Update output with the result of the compare registers
    o_led_bgr <= {
        pwm_compare >= ocr_b,
        pwm_compare >= ocr_g,
        pwm_compare >= ocr_r
    };
end

// Since the incoming wishbone address from the CPU increments by 4 bytes, we
// need to right shift it by 2 to get our actual register index
localparam reg_sel_bits = $clog2(wb_r_MAX + 1);
wire [reg_sel_bits-1:0] register_index = i_wb_adr[reg_sel_bits+1:2];

always @(posedge i_clk) begin
    if (i_reset) begin
        o_wb_ack <= 0;
        pwm_prescaler <= 0;
    end else begin
        // Wishbone interface logic
        o_wb_ack <= 1'b0;
        if (i_wb_cyc && i_wb_stb && !o_wb_ack) begin
            o_wb_ack <= 1'b1;

            // Register read
            case (register_index)
                wb_r_PWM_PRESCALER: o_wb_dat <= pwm_prescaler;
                wb_r_BGR_DATA:      o_wb_dat <= {8'd0, ocr_b, ocr_g, ocr_r};
            endcase

            // Register write
            if (i_wb_we) begin
                case (register_index)
                    wb_r_PWM_PRESCALER: pwm_prescaler <= i_wb_dat;
                    wb_r_BGR_DATA: begin
                        ocr_b <= i_wb_dat[23:16];
                        ocr_g <= i_wb_dat[15:8];
                        ocr_r <= i_wb_dat[7:0];
                    end
                endcase
            end
        end
    end
end

endmodule
