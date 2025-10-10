`timescale 1ns/1ps

// =========================
// Top Module
// =========================
module top(
    input  wire       clk,
    input  wire       rst,
    input  wire       serial_in,

    output reg  [7:0] data_out,
    output reg        byte_valid,
    output reg  [7:0] intr,
    output reg        intr_ready,
    output reg  [3:0] count,
    output reg        rsc1_in1,
    output reg        rsc_in2,
    output wire       sys_in,
    output wire       parity1,
    output wire       parity2,
    output reg  [7:0] data_out1,
    output reg        intr_ready_r,
    output reg        intr_ready_2r,
    output reg        intr_ready_3r,
    output reg  [2:0] encoded_data
);

    // Internal registers
    reg [2:0] bit_count;
    reg [7:0] shift_reg;
    reg [2:0] positions [0:7];

    // Initialize bit-rearrangement positions
    initial begin
        positions[0] = 0;
        positions[1] = 4;
        positions[2] = 1;
        positions[3] = 5;
        positions[4] = 2;
        positions[5] = 6;
        positions[6] = 3;
        positions[7] = 7;
    end

    // Shift serial bits and form bytes
    always @(posedge clk) begin
        if (rst) begin
            bit_count       <= 3'd0;
            shift_reg       <= 8'd0;
            data_out        <= 8'd0;
            byte_valid      <= 1'b0;
            intr_ready      <= 1'b0;
            count           <= 4'd0;
            data_out1       <= 8'd0;
            rsc1_in1        <= 1'b0;
            rsc_in2         <= 1'b0;
            intr_ready_r    <= 1'b0;
            intr_ready_2r   <= 1'b0;
            intr_ready_3r   <= 1'b0;
            encoded_data    <= 3'b000;
            intr            <= 8'd0;
        end else begin
            // Shift in serial bit (MSB first)
            shift_reg <= {shift_reg[6:0], serial_in};
            bit_count <= bit_count + 1'b1;

            if (bit_count == 3'd7) begin
                data_out   <= {shift_reg[6:0], serial_in};
                byte_valid <= 1'b1;
                bit_count  <= 3'd0;
                intr_ready <= 1'b1;
            end else begin
                byte_valid <= 1'b0;
            end

            // Update delayed signals
            data_out1      <= data_out;
            intr_ready_r   <= intr_ready;
            intr_ready_2r  <= intr_ready_r;
            intr_ready_3r  <= intr_ready_2r;

            // Prepare RSC inputs
            if (intr_ready) begin
                count <= count + 1'b1;
                if (count == 4'd7) begin
                    rsc1_in1 <= data_out1[count];
                    rsc_in2  <= data_out1[positions[count]];
                    count    <= 4'd0;
                end else begin
                    rsc1_in1 <= data_out[count];
                    rsc_in2  <= data_out[positions[count]];
                end
            end

            // Collect RSC encoded outputs
            encoded_data[0] <= sys_in;
            encoded_data[1] <= parity1;
            encoded_data[2] <= parity2;
        end
    end

    // Instantiate RSC encoders
    rsc_en rsc1 (
        .clk(clk),
        .rst(rst),
        .data_in(rsc1_in1),
        .sys_out(sys_in),
        .parity_out(parity1)
    );

    rsc_en rsc2 (
        .clk(clk),
        .rst(rst),
        .data_in(rsc_in2),
        .parity_out(parity2)
    );

endmodule

// =========================
// Recursive Systematic Convolutional Encoder
// =========================
module rsc_en(
    input  wire clk,
    input  wire rst,
    input  wire data_in,       // input bit u_k
    output reg  sys_out,       // systematic output (u_k)
    output reg  parity_out     // parity output
);
    // Shift registers
    reg s0, s1, s2, s3;
    reg [4:0] temp;

    always @(posedge clk) begin
        if (rst) begin
            s0 <= 0; s1 <= 0; s2 <= 0; s3 <= 0;
            parity_out <= 0;
            sys_out    <= 0;
        end else begin
            // Systematic output
            sys_out = data_in;

            // Compute parity
            temp = {s3, s2, s1, s0, data_in ^ s2 ^ s3};
            parity_out <= temp[0] ^ temp[1] ^ temp[4];

            // Update shift registers
            s0 <= data_in ^ s2 ^ s3;
            s1 <= s0;
            s2 <= s1;
            s3 <= s2;
        end
    end
endmodule
