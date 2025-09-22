`timescale 1ns / 1ps

module turbo_decoding #(
    parameter N = 24  // block size (multiple of 3)
)(
    input wire clk,
    input wire rst,
    input wire signed [7:0] ip,      // serial encoded input (sys+parity1+parity2)
    output reg signed [7:0] sys_in,
    output reg signed [7:0] parity1,
    output reg signed [7:0] parity2,
    output reg read_flag
);

    reg [7:0] rd_addr;
    reg reading;
    reg [3:0] read_count;

    reg signed [7:0] ram[0:N*3-1];  // assume input loaded elsewhere

    reg signed [7:0] data_sys[0:7];
    reg signed [7:0] data_par1[0:7];
    reg signed [7:0] data_par2[0:7];

    // Buffers
    reg signed [7:0] buffer2[0:7];
    reg signed [7:0] buffer3[0:7];
    reg signed [7:0] gamma_buffer[0:3][0:1][0:7];

    reg [3:0] count;
    reg buffer_ready;
    reg buffer_ready_r, buffer_ready_2r;

    // Alpha / Beta buffers
    reg signed [7:0] alpha_buff[0:3][0:8];
    reg signed [7:0] beta_buff[0:3][0:9];
    reg [3:0] buff_count;
    reg [3:0] up_count;

    // Temp variables
    reg signed [7:0] temp1,temp2,temp3,temp4,temp5,temp6,temp7,temp8;
    reg signed [7:0] b1,b2,b3,b4,b5,b6,b7,b8;

    // LLR calculation
    reg alpha_beta_done, alpha_beta_done_r, alpha_beta_done_2r;
    reg [3:0] llr_count;
    reg signed [7:0] num, den;
    reg signed [7:0] val10,val11,val20,val21,val30,val31,val40,val41;
    reg signed [7:0] Lapp,Lext;
    reg signed [7:0] L_ext[0:7];

    // ---------------- READ LOGIC ----------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sys_in     <= 0;
            parity1    <= 0;
            parity2    <= 0;
            rd_addr    <= 0;
            read_count <= 0;
            reading    <= 0;
            read_flag  <= 0;
        end else if (reading) begin
            sys_in   <= ram[rd_addr];
            parity1  <= ram[rd_addr + 1];
            parity2  <= ram[rd_addr + 2];

            rd_addr    <= rd_addr + 3;
            read_count <= read_count + 1'b1;

            data_sys[read_count]  <= sys_in;
            data_par1[read_count] <= parity1;
            data_par2[read_count] <= parity2;

            if (read_count == 7) begin
                reading   <= 0;
                read_flag <= 0;
            end
        end
    end

    // ---------------- GAMMA BUFFER ----------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count        <= 0;
            buffer_ready <= 0;
        end else if (read_flag) begin
            gamma_buffer[0][0][count] <= g_111;
            gamma_buffer[0][1][count] <= g_121;
            gamma_buffer[1][0][count] <= g_211;
            gamma_buffer[1][1][count] <= g_221;
            gamma_buffer[2][0][count] <= g_311;
            gamma_buffer[2][1][count] <= g_321;
            gamma_buffer[3][0][count] <= g_411;
            gamma_buffer[3][1][count] <= g_421;

            count <= count + 1'b1;
            if (count == 4'd7) begin
                buffer_ready <= 1;
                count        <= 0;
            end
        end
    end

    // ---------------- ALPHA / BETA UPDATE ----------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            up_count       <= 0;
            buffer_ready_r <= 0;
            buffer_ready_2r <= 0;
            buff_count     <= 0;
        end else begin
            buffer_ready_r  <= buffer_ready;
            buffer_ready_2r <= buffer_ready_r;

            if (buffer_ready) begin
                buff_count <= buff_count + 1'b1;
                if (buff_count >= 7) begin
                    buff_count   <= 0;
                    buffer_ready <= 0;
                end

                // TEMP alpha candidates
                temp1 <= (alpha_buff[0][buff_count+1] >= alpha_buff[0][buff_count] + gamma_buffer[0][0][buff_count]) ?
                          alpha_buff[0][buff_count+1] : alpha_buff[0][buff_count] + gamma_buffer[0][0][buff_count];
                temp5 <= (alpha_buff[2][buff_count+1] >= alpha_buff[0][buff_count] + gamma_buffer[0][1][buff_count]) ?
                          alpha_buff[2][buff_count+1] : alpha_buff[0][buff_count] + gamma_buffer[0][1][buff_count];
                temp6 <= (alpha_buff[2][buff_count+1] >= alpha_buff[1][buff_count] + gamma_buffer[1][0][buff_count]) ?
                          alpha_buff[2][buff_count+1] : alpha_buff[1][buff_count] + gamma_buffer[1][0][buff_count];
                temp2 <= (alpha_buff[0][buff_count+1] >= alpha_buff[1][buff_count] + gamma_buffer[1][1][buff_count]) ?
                          alpha_buff[0][buff_count+1] : alpha_buff[1][buff_count] + gamma_buffer[1][1][buff_count];
                temp3 <= (alpha_buff[1][buff_count+1] >= alpha_buff[2][buff_count] + gamma_buffer[2][0][buff_count]) ?
                          alpha_buff[1][buff_count+1] : alpha_buff[3][buff_count] + gamma_buffer[2][0][buff_count];
                temp7 <= (alpha_buff[3][buff_count+1] >= alpha_buff[2][buff_count] + gamma_buffer[2][1][buff_count]) ?
                          alpha_buff[2][buff_count+1] : alpha_buff[3][buff_count] + gamma_buffer[2][1][buff_count];
                temp8 <= (alpha_buff[3][buff_count+1] >= alpha_buff[3][buff_count] + gamma_buffer[3][0][buff_count]) ?
                          alpha_buff[3][buff_count+1] : alpha_buff[3][buff_count] + gamma_buffer[3][0][buff_count];
                temp4 <= (alpha_buff[1][buff_count+1] >= alpha_buff[3][buff_count] + gamma_buffer[3][1][buff_count]) ?
                          alpha_buff[1][buff_count+1] : alpha_buff[3][buff_count] + gamma_buffer[3][1][buff_count];

                // TEMP beta candidates
                b1 <= (beta_buff[0][9-buff_count+1] >= beta_buff[0][8-buff_count] + gamma_buffer[0][0][7-buff_count]) ?
                      beta_buff[0][9-buff_count+1] : beta_buff[0][8-buff_count] + gamma_buffer[0][0][7-buff_count];
                b2 <= (beta_buff[1][9-buff_count+1] >= beta_buff[1][8-buff_count] + gamma_buffer[1][1][7-buff_count]) ?
                      beta_buff[1][9-buff_count+1] : beta_buff[1][8-buff_count] + gamma_buffer[1][1][7-buff_count];
                b3 <= (beta_buff[1][9-buff_count+1] >= beta_buff[2][8-buff_count] + gamma_buffer[2][0][7-buff_count]) ?
                      beta_buff[1][9-buff_count+1] : beta_buff[3][8-buff_count] + gamma_buffer[2][0][7-buff_count];
                b4 <= (beta_buff[3][9-buff_count+1] >= beta_buff[3][8-buff_count] + gamma_buffer[3][1][7-buff_count]) ?
                      beta_buff[3][9-buff_count+1] : beta_buff[3][8-buff_count] + gamma_buffer[3][1][7-buff_count];
                b5 <= (beta_buff[2][9-buff_count+1] >= beta_buff[0][8-buff_count] + gamma_buffer[0][1][7-buff_count]) ?
                      beta_buff[2][9-buff_count+1] : beta_buff[0][8-buff_count] + gamma_buffer[0][1][7-buff_count];
                b6 <= (beta_buff[2][9-buff_count+1] >= beta_buff[1][8-buff_count] + gamma_buffer[1][0][7-buff_count]) ?
                      beta_buff[2][9-buff_count+1] : beta_buff[1][8-buff_count] + gamma_buffer[1][0][7-buff_count];
                b7 <= (beta_buff[3][9-buff_count+1] >= beta_buff[2][8-buff_count] + gamma_buffer[2][1][7-buff_count]) ?
                      beta_buff[2][9-buff_count+1] : beta_buff[3][8-buff_count] + gamma_buffer[2][1][7-buff_count];
                b8 <= (beta_buff[3][9-buff_count+1] >= beta_buff[3][8-buff_count] + gamma_buffer[3][0][7-buff_count]) ?
                      beta_buff[3][9-buff_count+1] : beta_buff[3][8-buff_count] + gamma_buffer[3][0][7-buff_count];
            end

            // Update alpha / beta
            if (buffer_ready_r || buffer_ready_2r) begin
                up_count <= up_count + 1'b1;
                if (up_count >= 7)
                    up_count <= 0;
                else begin
                    alpha_buff[0][up_count+1] <= (temp1 >= temp2) ? temp1 : temp2;
                    alpha_buff[1][up_count+1] <= (temp3 >= temp4) ? temp3 : temp4;
                    alpha_buff[2][up_count+1] <= (temp5 >= temp6) ? temp5 : temp6;
                    alpha_buff[3][up_count+1] <= (temp7 >= temp8) ? temp7 : temp8;

                    beta_buff[0][9-up_count+1] <= (b1 >= b2) ? b1 : b2;
                    beta_buff[1][9-up_count+1] <= (b3 >= b4) ? b3 : b4;
                    beta_buff[2][9-up_count+1] <= (b5 >= b6) ? b5 : b6;
                    beta_buff[3][9-up_count+1] <= (b7 >= b8) ? b7 : b8;
                end
            end
        end
    end

    // ---------------- ALPHA-BETA DONE FLAG ----------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            alpha_beta_done   <= 0;
            alpha_beta_done_r <= 0;
            alpha_beta_done_2r <= 0;
        end else begin
            if (buffer_ready) begin
                alpha_beta_done <= 0;
            end else begin
                alpha_beta_done <= 1;
            end
            alpha_beta_done_r   <= alpha_beta_done;
            alpha_beta_done_2r  <= alpha_beta_done_r;
        end
    end

    // ---------------- LLR CALCULATION ----------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            llr_count <= 0;
            num <= -127; den <= -127;
            val10<= -127; val11<= -127; val20<= -127; val21<= -127;
            val30<= -127; val31<= -127; val40<= -127; val41<= -127;
            Lapp <= 0; Lext <= 0;
        end else if (alpha_beta_done) begin
            llr_count <= llr_count + 1'b1;
            if (llr_count >= 7) llr_count <= 0;
        end else begin
            val10 <= alpha_buff[0][llr_count] + gamma_buffer[0][0][llr_count] + beta_buff[0][llr_count+1];
            val11 <= alpha_buff[0][llr_count] + gamma_buffer[0][1][llr_count] + beta_buff[2][llr_count+1];
            val20 <= alpha_buff[1][llr_count] + gamma_buffer[1][0][llr_count] + beta_buff[2][llr_count+1];
            val21 <= alpha_buff[1][llr_count] + gamma_buffer[1][1][llr_count] + beta_buff[0][llr_count+1];
            val30 <= alpha_buff[2][llr_count] + gamma_buffer[2][0][llr_count] + beta_buff[1][llr_count+1];
            val31 <= alpha_buff[2][llr_count] + gamma_buffer[2][1][llr_count] + beta_buff[3][llr_count+1];
            val40 <= alpha_buff[3][llr_count] + gamma_buffer[3][0][llr_count] + beta_buff[3][llr_count+1];
            val41 <= alpha_buff[3][llr_count] + gamma_buffer[3][1][llr_count] + beta_buff[1][llr_count+1];

           

            Lapp <= num - den;
            Lext <= Lapp - data_sys[llr_count] - data_par1[llr_count];
            L_ext[llr_count] <= Lext;
        end
    end

    // ---------------- MODULES ----------------
    branch_metric_calculation bmc(
        clk,
        !read_flag,
        sys_in, parity1,
        g_111,g_121,g_211,g_221,g_311,g_321,g_411,g_421
    );
     // Compute maximums
            maximum m1(val10,val20,val30,val40,num);
            maximum m2(val11,val21,val31,val41,den);

endmodule


// ---------------- MAXIMUM FUNCTION ----------------
module maximum(a,b,c,d,max);
    input signed [7:0] a,b,c,d;
    output wire signed [7:0] max;
    wire signed [7:0] max1,max2;

    assign max1 = (a>=b)? a : b;
    assign max2 = (c>=d)? c : d;
    assign max  = (max1>=max2)? max1 : max2;
endmodule


`timescale 1ns / 1ps
module branch_metric_calculation(
    input wire clk,
    input wire rst,                  // synchronous reset
    input wire enable,               // active-high enable for calculation
    input wire signed [7:0] L_sys,  // systematic input
    input wire signed [7:0] L_p1,   // parity1 input
    
    output reg signed [7:0] g_111,
    output reg signed [7:0] g_121,
    output reg signed [7:0] g_211,
    output reg signed [7:0] g_221,
    output reg signed [7:0] g_311,
    output reg signed [7:0] g_321,
    output reg signed [7:0] g_411,
    output reg signed [7:0] g_421
);

    // internal extrinsic input, assuming zero if not connected
    reg signed [7:0] La;
    
    always @(posedge clk) begin
        if (rst) begin
            g_111 <= 0;
            g_121 <= 0;
            g_211 <= 0;
            g_221 <= 0;
            g_311 <= 0;
            g_321 <= 0;
            g_411 <= 0;
            g_421 <= 0;
            La    <= 0;
        end else if (enable) begin
            g_111 <= (-La - L_sys - L_p1) >>> 1;
            g_121 <= ( La + L_sys - L_p1) >>> 1;
            g_211 <= (-La - L_sys + L_p1) >>> 1;
            g_221 <= ( La + L_sys + L_p1) >>> 1;
            g_311 <= (-La - L_sys + L_p1) >>> 1;
            g_321 <= ( La + L_sys + L_p1) >>> 1;
            g_411 <= (-La - L_sys - L_p1) >>> 1;
            g_421 <= ( La + L_sys - L_p1) >>> 1;
        end else begin
            g_111 <= 0;
            g_121 <= 0;
            g_211 <= 0;
            g_221 <= 0;
            g_311 <= 0;
            g_321 <= 0;
            g_411 <= 0;
            g_421 <= 0;
        end
    end
endmodule

