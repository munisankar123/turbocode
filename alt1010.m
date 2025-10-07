clc;
clear all;
close all;

%% ----------------------------
% Custom Upsample Function
%% ----------------------------
function y = upsample_custom(x, sps)
    y = zeros(1, length(x)*sps);
    y(1:sps:end) = x;
end

%% ----------------------------
% RSC Encoder Function
%% ----------------------------
function [sys, parity, m1, m2] = rsc_encode(data_in, m1, m2)
    sys = data_in;
    parity = bitxor(data_in, m1);
    new_m2 = m1;
    new_m1 = bitxor(bitxor(data_in, m1), m2);
    m1 = new_m1;
    m2 = new_m2;
end

%% ----------------------------
% Custom Root Raised Cosine (RRC) filter generator
%% ----------------------------
function h = rrc_filter(beta, span, sps)
    N = span * sps;
    t = (-N/2:N/2) / sps;
    h = zeros(size(t));
    for i = 1:length(t)
        if t(i) == 0
            h(i) = 1 - beta + (4*beta/pi);
        elseif abs(t(i)) == 1/(4*beta)
            h(i) = (beta/sqrt(2))*((1+2/pi)*sin(pi/(4*beta)) + (1-2/pi)*cos(pi/(4*beta)));
        else
            h(i) = (sin(pi*t(i)*(1-beta)) + 4*beta*t(i)*cos(pi*t(i)*(1+beta))) / ...
                   (pi*t(i)*(1-(4*beta*t(i))^2));
        end
    end
    h = h / sqrt(sum(h.^2)); % normalize energy
end

%% ----------------------------
% Input Data (alt1010 pattern)
%% ----------------------------
data_in = repmat([1 0 1 0], 1, 8); % 32-bit repeated pattern
positions = [0 4 1 5 2 6 3 7] + 1; % Interleaver positions

%% ----------------------------
% Turbo Encoding (Rate 1/3)
%% ----------------------------
m1_1 = 0; m2_1 = 0; % Encoder 1 memory
m1_2 = 0; m2_2 = 0; % Encoder 2 memory
encoded_sys = [];
encoded_p1 = [];
encoded_p2 = [];

nBlocks = length(data_in)/8;
for blk = 1:nBlocks
    idx_start = (blk-1)*8 + 1;
    idx_end   = blk*8;
    block_bits = data_in(idx_start:idx_end);

    % Interleaved block
    intr_bits = block_bits(positions);

    for i = 1:8
        [sys1, p1, m1_1, m2_1] = rsc_encode(block_bits(i), m1_1, m2_1);
        [~, p2, m1_2, m2_2] = rsc_encode(intr_bits(i), m1_2, m2_2);
        encoded_sys(end+1) = sys1;
        encoded_p1(end+1)  = p1;
        encoded_p2(end+1)  = p2;
    end
end

%% ----------------------------
% Combine Encoded Bits (Rate 1/3)
%% ----------------------------
encoded_bits = reshape([encoded_sys; encoded_p1; encoded_p2], 1, []);

%% ----------------------------
% BPSK Modulation
%% ----------------------------
bpsk_symbols = 2*encoded_bits - 1; % 0→-1, 1→+1

%% ----------------------------
% RRC Filtering
%% ----------------------------
beta = 0.35; span = 6; sps = 8;
rrcFilter = rrc_filter(beta, span, sps);
tx_shaped = conv(upsample_custom(bpsk_symbols, sps), rrcFilter, 'same');

%% ----------------------------
% Spectrum Visualization
%% ----------------------------
fs = 7200; % bit rate after coding
Nfft = 8192;
spec = abs(fftshift(fft(tx_shaped, Nfft)));
spec = spec / max(spec);
freq = linspace(-fs/2, fs/2, Nfft);

figure;
plot(freq/1e3, 20*log10(spec));
grid on;
xlabel('Frequency (kHz)');
ylabel('Magnitude (dB)');
title('Spectrum of BPSK Modulated Turbo-Coded (Rate 1/3) Signal');
axis([-fs/2/1e3 fs/2/1e3 -60 0]);
