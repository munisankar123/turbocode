`timescale 1ns / 1ps

module rsc_decoding #(
    parameter N = 24              // block size (multiple of 3) -> N/3 = 8
)(
    input   clk,
    input   rst,
    input   signed [7:0] ip,    // 8-bit signed input (streamed: sys, par1, par2, ...)
    output reg  signed [7:0] sys_in,
    output reg  signed [7:0] parity1,
    output reg  signed [7:0] parity2,
    output reg  read_flag_r,
    output reg [7:0] wr_addr,
    output reg [7:0] rd_addr,
    output reg signed [7:0] data_sys,
    output reg signed [7:0] data_par1,
    output reg signed [7:0] data_par2,
    output reg buffer_ready,
    output reg signed [7:0] c1,c2,c3,c4,c5,c6,c7,c8,
    output reg [3:0] count_buff,
    output reg [4:0] count_disp,

    // alpha/beta debug outputs & flags
    output reg alpha_done,
    output reg beta_done,
    output reg signed [7:0] d1,d2,d3,d4,d5,d6,d7,d8,d9,
    output reg signed [7:0] e1,e2,e3,e4,e5,e6,e7,e8,e9
);

    // ------------------------------
    // gamma and related buffers
    // ------------------------------
    reg signed [7:0] gamma_buff[0:3][0:1][0:7]; // [state][u][time]
    reg signed [7:0] La_buff[0:7];

    // RAM and read state
    reg signed [7:0] ram [0:255];
    reg [3:0] read_count;
    reg reading;
    reg read_flag;

    // Intermediate buffers (hold one block = 8 samples)
    reg signed [7:0] buffer_sys [0:7];
    reg signed [7:0] buffer_par1 [0:7];
    reg signed [7:0] buffer_par2 [0:7];

    // gamma temporaries
    reg signed [7:0] g111,g121,g211,g221,g311,g321,g411,g421;

    // sequential gamma compute
    reg compute_gamma;
    reg [3:0] gamma_index; // 0..7
    reg [7:0]alpha_buff[0:3][0:8];
    reg [7:0]beta_buff[0:3][0:8];
    integer ii,jj;

    // ------------------- Initialization --------------------
    initial begin
        for (ii = 0; ii < 8; ii = ii + 1) La_buff[ii] = 0;
    end

    // ------------------- RAM WRITE & READ --------------------
    always @(posedge clk) begin
        if (rst) begin
            wr_addr    <= 0; rd_addr <= 0;
            read_count <= 0; reading <= 0;
            sys_in <= 0; parity1 <= 0; parity2 <= 0;
            read_flag <= 0; data_sys <= 0; data_par1 <= 0; data_par2 <= 0;
            count_disp <= 0; compute_gamma <= 0; buffer_ready <= 0; read_flag_r <= 0;
            count_buff <= 0; gamma_index <= 0;
            alpha_done <= 0; beta_done <= 0;

            // clear gamma
            for (ii = 0; ii < 8; ii = ii + 1) begin
                gamma_buff[0][0][ii] <= -127; gamma_buff[0][1][ii] <= -127;
                gamma_buff[1][0][ii] <= -127; gamma_buff[1][1][ii] <= -127;
                gamma_buff[2][0][ii] <= -127; gamma_buff[2][1][ii] <= -127;
                gamma_buff[3][0][ii] <= -127; gamma_buff[3][1][ii] <= -127;
            end

            // clear alpha
            for (jj = 0; jj < 9; jj = jj + 1) begin
                alpha_buff[0][jj] <= (jj==0) ? 0 : -127;
                alpha_buff[1][jj] <= -127;
                alpha_buff[2][jj] <= -127;
                alpha_buff[3][jj] <= -127;
            end

            // clear outputs
            c1<=0; c2<=0; c3<=0; c4<=0; c5<=0; c6<=0; c7<=0; c8<=0;
            d1<=0;d2<=0;d3<=0;d4<=0;d5<=0;d6<=0;d7<=0;d8<=0;d9<=0;
            e1<=0;e2<=0;e3<=0;e4<=0;e5<=0;e6<=0;e7<=0;e8<=0;e9<=0;
        end else begin
            // Write streaming input into RAM sequentially
            ram[wr_addr] <= ip;
            wr_addr <= (wr_addr == 8'd240) ? 0 : wr_addr + 1;
            read_flag_r <= read_flag;

            // Start reading when block full
            if (!reading && (wr_addr != 0) && (wr_addr % N == 0)) begin
                reading    <= 1;
                read_flag  <= 1;
                rd_addr    <= wr_addr - N;
                read_count <= 0;
                buffer_ready <= 0; alpha_done <= 0; beta_done <= 0;
            end

            // Read N/3 (=8) triplets into buffers
            if (reading) begin
                sys_in   <= ram[rd_addr];
                parity1  <= ram[rd_addr + 1];
                parity2  <= ram[rd_addr + 2];

                buffer_sys[read_count]  <= ram[rd_addr];
                buffer_par1[read_count] <= ram[rd_addr + 1];
                buffer_par2[read_count] <= ram[rd_addr + 2];

                data_sys  <= ram[rd_addr];
                data_par1 <= ram[rd_addr + 1];
                data_par2 <= ram[rd_addr + 2];

                rd_addr    <= rd_addr + 3;
                read_count <= read_count + 1;

                if (read_count == 4'd7) begin
                    reading   <= 0;
                    read_flag <= 0;
                    compute_gamma <= 1;
                    gamma_index <= 0;
                end
            end
        end
    end

    // ------------------- GAMMA COMPUTATION --------------------
    always @(posedge clk) begin
        if (rst) begin
            compute_gamma <= 0; gamma_index <= 0;
        end else if (compute_gamma) begin
            // Compute gamma
            g111 = ( buffer_sys[gamma_index] + La_buff[gamma_index] + buffer_par1[gamma_index] ) >>> 1;
            g121 = ( -buffer_sys[gamma_index] - La_buff[gamma_index] - buffer_par1[gamma_index] ) >>> 1;
            g211 = ( buffer_sys[gamma_index] + La_buff[gamma_index] + buffer_par2[gamma_index] ) >>> 1;
            g221 = ( -buffer_sys[gamma_index] - La_buff[gamma_index] - buffer_par2[gamma_index] ) >>> 1;
            g311 = ( buffer_sys[gamma_index] + La_buff[gamma_index] - buffer_par1[gamma_index] ) >>> 1;
            g321 = ( -buffer_sys[gamma_index] - La_buff[gamma_index] + buffer_par1[gamma_index] ) >>> 1;
            g411 = ( buffer_sys[gamma_index] + La_buff[gamma_index] - buffer_par2[gamma_index] ) >>> 1;
            g421 = ( -buffer_sys[gamma_index] - La_buff[gamma_index] + buffer_par2[gamma_index] ) >>> 1;

            gamma_buff[0][0][gamma_index] <= g111; gamma_buff[0][1][gamma_index] <= g121;
            gamma_buff[1][0][gamma_index] <= g211; gamma_buff[1][1][gamma_index] <= g221;
            gamma_buff[2][0][gamma_index] <= g311; gamma_buff[2][1][gamma_index] <= g321;
            gamma_buff[3][0][gamma_index] <= g411; gamma_buff[3][1][gamma_index] <= g421;

            if (gamma_index == 4'd7) begin
                compute_gamma <= 0;
                buffer_ready <= 1;
                count_disp <= 0;
            end else gamma_index <= gamma_index + 1'b1;
        end
    end

    // ------------------- OUTPUT c1..c8 (gamma display) --------------------
    always @(posedge clk) begin
        if (rst) begin
            c1<=0; c2<=0; c3<=0; c4<=0; c5<=0; c6<=0; c7<=0; c8<=0;
            count_disp <= 0;
        end else if (buffer_ready) begin
            c1 <= gamma_buff[0][0][count_disp];
            c2 <= gamma_buff[0][1][count_disp];
            c3 <= gamma_buff[1][0][count_disp];
            c4 <= gamma_buff[1][1][count_disp];
            c5 <= gamma_buff[2][0][count_disp];
            c6 <= gamma_buff[2][1][count_disp];
            c7 <= gamma_buff[3][0][count_disp];
            c8 <= gamma_buff[3][1][count_disp];

            count_disp <= (count_disp == 4'd7) ? 0 : count_disp + 1'b1;
        end
    end

    // ------------------- ALPHA CALCULATION --------------------
    reg [3:0] alpha_index;
    reg [3:0]beta_index;
    reg alpha_running;
    reg beta_done;

    always @(posedge clk) begin
        if (rst) begin
            alpha_index <= 0;
            alpha_done  <= 0;
            beta_done<=0;
            alpha_running <= 0;
            d1<=0;d2<=0;d3<=0;d4<=0;d5<=0;d6<=0;d7<=0;d8<=0;d9<=0;
        end else if (buffer_ready) begin
            if (!alpha_running) begin
                alpha_running <= 1;
                alpha_index <= 0;
                alpha_done <= 0;
            end else begin
                // Forward recursion for alpha
                alpha_buff[0][alpha_index+1] <= (alpha_buff[0][alpha_index+1] >= alpha_buff[0][alpha_index] + gamma_buff[0][0][alpha_index]) ?
                                                alpha_buff[0][alpha_index+1] : alpha_buff[0][alpha_index] + gamma_buff[0][0][alpha_index];
                alpha_buff[2][alpha_index+1] <= (alpha_buff[2][alpha_index+1] >= alpha_buff[0][alpha_index] + gamma_buff[0][1][alpha_index]) ?
                                                alpha_buff[2][alpha_index+1] : alpha_buff[0][alpha_index] + gamma_buff[0][1][alpha_index];

                alpha_buff[2][alpha_index+1] <= (alpha_buff[2][alpha_index+1] >= alpha_buff[1][alpha_index] + gamma_buff[1][0][alpha_index]) ?
                                                alpha_buff[2][alpha_index+1] : alpha_buff[1][alpha_index] + gamma_buff[1][0][alpha_index];
                alpha_buff[0][alpha_index+1] <= (alpha_buff[0][alpha_index+1] >= alpha_buff[1][alpha_index] + gamma_buff[1][1][alpha_index]) ?
                                                alpha_buff[0][alpha_index+1] : alpha_buff[1][alpha_index] + gamma_buff[1][1][alpha_index];

                alpha_buff[1][alpha_index+1] <= (alpha_buff[1][alpha_index+1] >= alpha_buff[2][alpha_index] + gamma_buff[2][0][alpha_index]) ?
                                                alpha_buff[1][alpha_index+1] : alpha_buff[2][alpha_index] + gamma_buff[2][0][alpha_index];
                alpha_buff[3][alpha_index+1] <= (alpha_buff[3][alpha_index+1] >= alpha_buff[2][alpha_index] + gamma_buff[2][1][alpha_index]) ?
                                                alpha_buff[3][alpha_index+1] : alpha_buff[2][alpha_index] + gamma_buff[2][1][alpha_index];

                alpha_buff[3][alpha_index+1] <= (alpha_buff[3][alpha_index+1] >= alpha_buff[3][alpha_index] + gamma_buff[3][0][alpha_index]) ?
                                                alpha_buff[3][alpha_index+1] : alpha_buff[3][alpha_index] + gamma_buff[3][0][alpha_index];
                alpha_buff[1][alpha_index+1] <= (alpha_buff[1][alpha_index+1] >= alpha_buff[3][alpha_index] + gamma_buff[3][1][alpha_index]) ?
                                                alpha_buff[1][alpha_index+1] : alpha_buff[3][alpha_index] + gamma_buff[3][1][alpha_index];
                                                
                beta_buff[0][beta_index+1] <= (beta_buff[0][beta_index+1] >= beta_buff[0][beta_index] + gamma_buff[0][0][beta_index]) ?
                                                beta_buff[0][beta_index+1] : beta_buff[0][beta_index] + gamma_buff[0][0][beta_index];
                beta_buff[2][beta_index+1] <= (beta_buff[2][beta_index+1] >= beta_buff[0][beta_index] + gamma_buff[0][1][beta_index]) ?
                                                beta_buff[2][beta_index+1] : beta_buff[0][beta_index] + gamma_buff[0][1][beta_index];

                beta_buff[2][beta_index+1] <= (beta_buff[2][beta_index+1] >= beta_buff[1][beta_index] + gamma_buff[1][0][beta_index]) ?
                                                beta_buff[2][beta_index+1] : beta_buff[1][beta_index] + gamma_buff[1][0][beta_index];
                beta_buff[0][beta_index+1] <= (beta_buff[0][beta_index+1] >= beta_buff[1][beta_index] + gamma_buff[1][1][beta_index]) ?
                                                beta_buff[0][beta_index+1] : beta_buff[1][beta_index] + gamma_buff[1][1][beta_index];

                beta_buff[1][beta_index+1] <= (beta_buff[1][beta_index+1] >= beta_buff[2][beta_index] + gamma_buff[2][0][beta_index]) ?
                                                beta_buff[1][beta_index+1] : beta_buff[2][beta_index] + gamma_buff[2][0][beta_index];
                beta_buff[3][beta_index+1] <= (beta_buff[3][beta_index+1] >= beta_buff[2][beta_index] + gamma_buff[2][1][beta_index]) ?
                                                beta_buff[3][beta_index+1] : beta_buff[2][beta_index] + gamma_buff[2][1][beta_index];

                beta_buff[3][beta_index+1] <= (beta_buff[3][beta_index+1] >= beta_buff[3][beta_index] + gamma_buff[3][0][beta_index]) ?
                                                beta_buff[3][beta_index+1] : beta_buff[3][beta_index] + gamma_buff[3][0][beta_index];
                beta_buff[1][beta_index+1] <= (beta_buff[1][beta_index+1] >= beta_buff[3][beta_index] + gamma_buff[3][1][beta_index]) ?
                                                beta_buff[1][beta_index+1] : beta_buff[3][beta_index] + gamma_buff[3][1][beta_index];
                                                
                                                     
                         
                // Update debug outputs
                d1 <= alpha_buff[0][alpha_index+1]; d2 <= alpha_buff[1][alpha_index+1];
                d3 <= alpha_buff[2][alpha_index+1]; d4 <= alpha_buff[3][alpha_index+1];

                          
                // Update debug outputs
                e1 <= alpha_buff[0][alpha_index+1]; e2 <= alpha_buff[1][alpha_index+1];
                e3 <= alpha_buff[2][alpha_index+1]; e4 <= alpha_buff[3][alpha_index+1];

                if (alpha_index == 4'd7) begin
                    alpha_done <= 1;
                    beta_done<=1;
                    alpha_running <= 0;
                end else alpha_index <= alpha_index + 1'b1;beta_index<=beta_index+1'b1;
            end
        end
    end
    
    
    always@(posedge clk)begin
        if(alpha_done==1 && beta_done==1)begin
        
        end
    end

endmodule
