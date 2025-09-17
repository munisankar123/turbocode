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
    output reg  read_flag,
    output reg [7:0] wr_addr,
    output reg [7:0] rd_addr
);

    // Internal RAM for storing encoded bits
    reg ram [0:255];               // circular buffer, 256 bits
    reg [7:0] count;               // number of valid bits collected
    reg reading;                   // read mode flag

    always @(posedge clk) begin
        if (rst) begin
            wr_addr   <= 0;
            rd_addr   <= 0;
            count     <= 0;
            reading   <= 0;
            sys_in    <= 0;
            parity1   <= 0;
            parity2   <= 0;
            read_flag <= 0;
        end else begin
            // ---------------- WRITE LOGIC ----------------
            ram[wr_addr] <= ip;                    
            if (wr_addr == 8'd255)
                wr_addr <= 0;                      
            else
                wr_addr <= wr_addr + 1'b1;

            // Update count of how many bits received (saturates at N)
            if (count < N)
                count <= count + 1'b1;

            // ---------------- READ CONTROL ----------------
            // When at least N bits received, enable reading
            if (count >= N && !reading) begin
                reading   <= 1;
                read_flag <= 1;
                rd_addr   <= 0;        // start from beginning of block
            end

            // ---------------- READ LOGIC ----------------
            if (reading) begin
                sys_in  <= ram[rd_addr];       
                parity1 <= ram[rd_addr + 1];    
                parity2 <= ram[rd_addr + 2];   

                // Stop when we reach rd_addr=21 (last triplet in block of 24)
                if (rd_addr >= (N-3)) begin
                    reading   <= 0;    // stop reading
                    read_flag <= 0;    // clear flag
                    count     <= 0;    // reset counter for next block
                end else begin
                    rd_addr <= rd_addr + 3;    // next triplet
                end
            end
        end
    end

endmodule
