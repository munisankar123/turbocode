`timescale 1ns / 1ps

module rsc_decoding #(
    parameter N = 24              // block size (multiple of 3)
)(
    input  wire clk,
    input  wire rst,
    input  wire ip,                // serial encoded input (systematic + parity1 + parity2)
    output reg  sys_in,
    output reg  parity1,
    output reg  parity2,
    output reg  read_flag_r,
    output reg [7:0] wr_addr,
    output reg [7:0] rd_addr,
    output reg [7:0]data_sys,
    output reg [7:0]data_par1,
    output reg [7:0]data_par2
);
    reg ram [0:255];               
    reg [3:0] read_count;          
    reg reading;
    reg read_flag;
    reg [2:0]bit_count;
    reg [7:0]shift_reg1;
    reg [7:0]shift_reg2;
    reg [7:0]shift_reg3;
    reg byte_valid;
    always @(posedge clk) begin
        if (rst) begin
            wr_addr    <= 0;
            rd_addr    <= 0;
            read_count <= 0;
            reading    <= 0;
            sys_in     <= 0;
            parity1    <= 0;
            parity2    <= 0;
            read_flag  <= 0;
            
            bit_count  <= 3'd0;
            shift_reg1  <= 8'd0;
            shift_reg2  <= 8'd0;
            shift_reg3  <= 8'd0;
            data_sys   <= 8'd0;
            data_par1<=0;
            data_par2<=0;
            byte_valid <= 1'b0;
        end else begin
            ram[wr_addr] <= ip;                    
            if (wr_addr == 8'd240)
                wr_addr <= 0;                      
            else
                wr_addr <= wr_addr + 1'b1;

            read_flag_r <=read_flag;
            if (!reading && (wr_addr != 0) && (wr_addr % N == 0)) begin
                reading    <= 1;
                read_flag  <= 1;
                rd_addr    <= wr_addr - N;
                read_count <= 0;
            end
            
            
            

            // ---------------- READ LOGIC ----------------
            if (reading) begin
                // Output triplet
                sys_in  <= ram[rd_addr];       
                parity1 <= ram[rd_addr + 1];    
                parity2 <= ram[rd_addr + 2];   

                // Advance rd_addr and count
                rd_addr    <= rd_addr + 3;
                read_count <= read_count + 1'b1;

                // Stop after 8 triplets (24 bits)
                if (read_count == 7) begin
                    reading    <= 0;
                    read_flag  <= 0;
                end
            end
        end
    end

    
    
    always @(posedge clk) begin
        if(read_flag_r==1) begin
            shift_reg1 <= {shift_reg1[6:0], sys_in};
            shift_reg2 <= {shift_reg2[6:0], parity1};
            shift_reg3 <= {shift_reg3[6:0], parity2};
            
            bit_count <= bit_count + 1;

            if (bit_count == 3'd7) begin
                data_sys   <= {shift_reg1[6:0], sys_in};
                data_par1   <= {shift_reg2[6:0], parity1};
                data_par2   <= {shift_reg3[6:0], parity2};
                byte_valid <= 1'b1;
                bit_count  <= 3'd0;
            end else begin
                byte_valid <= 1'b0;
            end
        end
    end

endmodule
