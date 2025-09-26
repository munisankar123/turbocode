% Input sequence (32 bits in this case)
clc;
clear all;
close all;


% --- Function: RSC Encoder ---
function [sys, parity, m1, m2] = rsc_encode(data_in, m1, m2)
  sys = data_in;
  parity = bitxor(data_in, m1);
  new_m2 = m1;
  new_m1 = bitxor(bitxor(data_in, m1), m2);
  m1 = new_m1;
  m2 = new_m2;
end
data_in = [
  0 0 0 1 0 1 0 1 ...
  1 1 0 1 0 1 1 1 ...
  0 1 0 1 0 1 0 1 ...
  0 1 0 1 1 1 1 1 ...
  0 0 1 1 0 1 1 1 ...
  0 1 0 1 0 1 1 1 ...
  0 0 0 0 0 1 0 1 ...
  1 1 1 1 0 1 1 1
];
% Interleaver positions (1-based in MATLAB)
positions = [0 4 1 5 2 6 3 7] + 1;

% Initialize encoder states
m1_1 = 0; m2_1 = 0;
m1_2 = 0; m2_2 = 0;

% Output arrays
encoded_sys = [];
encoded_p1  = [];
encoded_p2  = [];

% Process blocks of 8
nBlocks = length(data_in)/8;
for blk = 1:nBlocks
  idx_start = (blk-1)*8 + 1;
  idx_end   = blk*8;
  block_bits = data_in(idx_start:idx_end);

  % Interleaved block
  intr_bits = block_bits(positions);

  for i = 1:8
    % Encoder1: systematic + parity1
    [sys1, p1, m1_1, m2_1] = rsc_encode(block_bits(i), m1_1, m2_1);
    % Encoder2: interleaved parity2
    [~, p2, m1_2, m2_2]   = rsc_encode(intr_bits(i), m1_2, m2_2);

    % Store
    encoded_sys(end+1) = sys1;
    encoded_p1(end+1)  = p1;
    encoded_p2(end+1)  = p2;
  end
end

encoded_sys
encoded_p1
encoded_p2
