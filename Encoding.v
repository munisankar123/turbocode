//==============================================================
// Recursive Systematic Convolutional (RSC) Encoder
// Polynomials:
//   Feedback (Gf)  = 23 (octal) = 10111 (binary)
//   Feedforward (Gff) = 31 (octal) = 11111 (binary)
//--------------------------------------------------------------
// Constraint length = 5 → 4 memory elements
//==============================================================

module rsc_encoder (
    input  wire clk,
    input  wire reset,
    input  wire data_in,      // Input bit (serial)
    output reg  sys_bit,      // Systematic output
    output reg  parity_bit    // Parity output
);

    // ----------------------------------------------------------
    // Internal shift registers (4 memory elements)
    // ----------------------------------------------------------
    reg m1, m2, m3, m4;

    // ----------------------------------------------------------
    // Feedback calculation (using 23 -> 10111)
    // feedback = data_in XOR m1 XOR m2 XOR m4
    // ----------------------------------------------------------
    wire feedback;
    assign feedback = data_in ^ m1 ^ m2 ^ m4;

    // ----------------------------------------------------------
    // Parity computation (using 31 -> 11111)
    // parity = feedback XOR m1 XOR m2 XOR m3 XOR m4
    // ----------------------------------------------------------
    wire parity;
    assign parity = feedback ^ m1 ^ m2 ^ m3 ^ m4;

    // ----------------------------------------------------------
    // Sequential logic: update registers and outputs
    // ----------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            m1 <= 0;
            m2 <= 0;
            m3 <= 0;
            m4 <= 0;
            sys_bit <= 0;
            parity_bit <= 0;
        end else begin
            // Output bits
            sys_bit    <= data_in;   // Systematic bit (unchanged input)
            parity_bit <= parity;    // Parity bit

            // Update shift registers (recursive part)
            m4 <= m3;
            m3 <= m2;
            m2 <= m1;
            m1 <= feedback;
        end
    end

endmodule
