`timescale 1ns/1ps

module tb_rsc_encoding;

    reg clk;
    reg rst;
    reg serial_in;

    wire [7:0] data_out;
    wire       byte_valid;
    wire [7:0] intr;
    wire       intr_ready;
    wire [3:0] count;
    wire       rsc1_in1;
    wire       rsc_in2;
    wire       sys_in;
    wire       parity1;
    wire       parity2;
    wire [2:0] encoded_data;
    wire   intr_ready_r;
    wire intr_ready_2r;
    wire intr_ready_3r;
    wire [7:0]data_out1;

    // DUT
    top dut (
        .clk(clk),
        .rst(rst),
        .serial_in(serial_in),
        .data_out(data_out),
        .byte_valid(byte_valid),
        .intr(intr),
        .intr_ready(intr_ready),
        .count(count),
        .rsc1_in1(rsc1_in1),
        .rsc_in2(rsc_in2),
        .sys_in(sys_in),
        .parity1(parity1),
        .parity2(parity2),
        .data_out1(data_out1),   
        .intr_ready_r(intr_ready_r),
        .intr_ready_2r(intr_ready_2r), 
        .intr_ready_3r(intr_ready_3r),     // not used in TB
        .encoded_data(encoded_data)
    );

    // Clock generation: period = 2 ns (toggle every 1ns)
    initial clk = 0;
    always #1 clk = ~clk;
    
    initial begin
        rst=1;
        #10
        rst=0;
        clk=1;
        serial_in=1;#2
        serial_in=0;#2
        serial_in=1;#2
        serial_in=0;#2
        serial_in=1;#2
        serial_in=0;#2
        serial_in=0;#2
        serial_in=0;#2
        
        serial_in=1;#2
        serial_in=1;#2
        serial_in=1;#2
        serial_in=0;#2
        serial_in=1;#2
        serial_in=0;#2
        serial_in=1;#2
        serial_in=1;#2
        
        serial_in=1;#2
        serial_in=0;#2
        serial_in=1;#2
        serial_in=0;#2
        serial_in=1;#2
        serial_in=0;#2
        serial_in=1;#2
        serial_in=0;#2
        
        serial_in=1;#2
        serial_in=1;#2
        serial_in=1;#2
        serial_in=1;#2
        serial_in=1;#2
        serial_in=0;#2
        serial_in=1;#2
        serial_in=0;#2
        
        serial_in=1;#2
        serial_in=1;#2
        serial_in=1;#2
        serial_in=0;#2
        serial_in=1;#2
        serial_in=1;#2
        serial_in=0;#2
        serial_in=0;#2
        
        serial_in=1;#2
        serial_in=1;#2
        serial_in=1;#2
        serial_in=0;#2
        serial_in=1;#2
        serial_in=0;#2
        serial_in=1;#2
        serial_in=0;#2
        
        serial_in=1;#2
        serial_in=0;#2
        serial_in=1;#2
        serial_in=0;#2
        serial_in=0;#2
        serial_in=0;#2
        serial_in=0;#2
        serial_in=0;#2
        
        serial_in=1;#2
        serial_in=1;#2
        serial_in=1;#2
        serial_in=0;#2
        serial_in=1;#2
        serial_in=1;#2
        serial_in=1;#2
        serial_in=1;
        
    end
endmodule
