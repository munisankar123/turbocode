`timescale 1ns/1ps

module tb_rsc_encoding;

    // -------------------
    // Clocks and Reset
    // -------------------
    reg sys_clk;
    reg clk_100MHz;
    reg mod_clk;
    reg rst;
    reg serial_in;

    // -------------------
    // Parameters
    // -------------------
    localparam SYS_CLK_PERIOD   = 2;     // 500 MHz (toggle every 1 ns)
    localparam CLK100_PERIOD    = 10;    // 100 MHz (toggle every 5 ns)
    localparam DATARATE         = 10_000_000; // 10 Mbps
    localparam MOD_CLK_PERIOD   = 100;   // bit period = 100 ns -> 10 MHz

    // -------------------
    // DUT connections
    // -------------------
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
    wire       intr_ready_r;
    wire       intr_ready_2r;
    wire       intr_ready_3r;
    wire [7:0] data_out1;

    // -------------------
    // DUT instantiation
    // -------------------
    top dut (
        .clk(clk_100MHz),          // give 100 MHz clock to DUT
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
        .intr_ready_3r(intr_ready_3r),     
        .encoded_data(encoded_data)
    );

    // -------------------
    // Clock Generation
    // -------------------
    initial begin
        sys_clk = 0;
        forever #(SYS_CLK_PERIOD/2) sys_clk = ~sys_clk;
    end

    initial begin
        clk_100MHz = 0;
        forever #(CLK100_PERIOD/2) clk_100MHz = ~clk_100MHz;
    end

    initial begin
        mod_clk = 0;
        forever #(MOD_CLK_PERIOD/2) mod_clk = ~mod_clk;
    end

    // -------------------
    // Stimulus
    // -------------------
    reg [7:0] data = 8'b10101011;  // example data byte
    integer i;

    initial begin
        rst = 1;
        serial_in = 0;
        #20 rst = 0;   // release reset

        // transmit serial data synchronized with mod_clk
        for (i = 0; i < 8; i = i + 1) begin
            @(posedge mod_clk);
            serial_in <= data[i];  // LSB-first
        end

        // hold last value
        @(posedge mod_clk);
        serial_in <= 1'b0;
    end

endmodule
