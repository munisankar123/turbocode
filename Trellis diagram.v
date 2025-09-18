`timescale 1ns/1ps
module trellis_15_7 (
    input  wire [1:0] state,     // current state {r1,r2}
    input  wire       u,         // input bit
    output reg  [1:0] next_state,
    output reg        sys,
    output reg        par
);

    always @(*) begin
        sys = u;  // systematic output always = input
        case (state)
            2'b00: begin
                if (u==0) begin next_state=2'b00; par=0; end
                else       begin next_state=2'b10; par=1; end
            end
            2'b01: begin
                if (u==0) begin next_state=2'b10; par=0; end
                else       begin next_state=2'b00; par=1; end
            end
            2'b10: begin
                if (u==0) begin next_state=2'b11; par=1; end
                else       begin next_state=2'b01; par=0; end
            end
            2'b11: begin
                if (u==0) begin next_state=2'b01; par=1; end
                else       begin next_state=2'b11; par=0; end
            end
            default: begin
                next_state=2'b00;
                par=0;
            end
        endcase
    end

endmodule
