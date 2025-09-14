`timescale 1ns/1ps

module rsc_encoding(
    input  wire clk,
    input  wire rst,
    input  wire serial_in,
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
    output reg        rd_en,       
    output reg        encoded_out_data, 
    output reg        intr_ready2,  
    output reg        ram_data_out  
);

    // Internal signals
    reg [2:0] bit_count;
    reg [7:0] shift_reg;
    reg [2:0] positions [0:7];
    reg [7:0] data_out1;
    reg [7:0] data_out2;
    reg [3:0] count1;
    reg intr_ready1;
    reg intr_ready3;
    reg rst2;

    reg ram [0:255];
    reg [7:0] wr_addr;
    reg [7:0] rd_addr;
    reg [7:0] wr_addr_prev;     
    reg [7:0] w0, w1, w2;
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
    always @(posedge clk) begin
        if (rst) begin
            intr       <= 8'd0;
            intr_ready <= 1'b0;
            intr_ready1 <= 1'b0;
            intr_ready2 <= 1'b0;
            count      <= 4'd0;
            count1     <= 4'd0;
            data_out1  <= 8'd0;
            data_out2  <= 8'd0;
            rsc1_in1   <= 1'b0;
            rsc_in2    <= 1'b0;
            wr_addr    <= 8'd0;
            rd_addr    <= 8'd0;
            wr_addr_prev <= 8'd0;
            rd_en      <= 1'b0;
            encoded_out_data <= 1'b0;
            ram_data_out     <= 1'b0;
        end else begin
            // delays for pipeline
            data_out1 <= data_out;
            data_out2 <= data_out1;
            intr_ready1 <= intr_ready;
            intr_ready2 <= intr_ready1;
            intr_ready2 <= intr_ready1;
            intr_ready2 <= intr_ready1;
            intr_ready3 <= intr_ready2;
            

            // rst2 (used for RSC blocks)
            if (intr_ready==1 || intr_ready1==1 || intr_ready2==1) begin
                rst2 <= 0;
            end else begin
                rst2 <= 1;
            end
            if (byte_valid) begin
                intr <= { data_out[positions[7]], data_out[positions[6]],
                          data_out[positions[5]], data_out[positions[4]],
                          data_out[positions[3]], data_out[positions[2]],
                          data_out[positions[1]], data_out[positions[0]] };
                intr_ready <= 1'b1;
                count      <= 4'd0;
                count1     <= 4'd0;
            end else begin
                if (intr_ready) begin
                    if (count == 4'd6) begin
                        intr_ready <= 1'b0;
                    end else begin
                        count <= count + 1'b1;
                    end
                end
            end
            if (intr_ready) begin
                count1 <= count1 + 1'b1;
                if (count1 >= 4'd2) begin
                    rsc1_in1 <= data_out2[count];
                    rsc_in2  <= intr[count];
                end else begin
                    rsc1_in1 <= data_out1[count];
                    rsc_in2  <= intr[count];
                end
            end
            
            if (intr_ready2 || intr_ready3) begin
                w0 = wr_addr;
                w1 = wr_addr + 8'd1;
                w2 = wr_addr + 8'd2;
                ram[w0] <= sys_in;
                ram[w1] <= parity1;
                ram[w2] <= parity2;
                wr_addr <= wr_addr + 8'd3;
            end
            if (wr_addr_prev >= 8'd3) begin
                rd_en <= 1'b1; 
            end
            if (rd_en) begin
                encoded_out_data <= ram[rd_addr];
                ram_data_out     <= ram[rd_addr]; // expose same value
                rd_addr <= rd_addr + 8'd1;
            end
            wr_addr_prev <= wr_addr;
        end
    end

    rsc_en1 rsc1(.clk(clk), .rst(rst2), .data_in(rsc1_in1), .sys_out(sys_in), .parity_out(parity1));
    rsc_en2 rsc2(.clk(clk), .rst(rst2), .data_in(rsc_in2), .parity_out(parity2));
    always @(posedge clk) begin
        if (rst) begin
            bit_count  <= 3'd0;
            shift_reg  <= 8'd0;
            data_out   <= 8'd0;
            byte_valid <= 1'b0;
        end else begin
            shift_reg <= {shift_reg[6:0], serial_in};
            bit_count <= bit_count + 1;

            if (bit_count == 3'd7) begin
                data_out   <= {shift_reg[6:0], serial_in};
                byte_valid <= 1'b1;
                bit_count  <= 3'd0;
            end else begin
                byte_valid <= 1'b0;
            end
        end
    end

endmodule
