% turbo_rsc_maxlogmap.m
% Self-contained Turbo encoder/decoder with puncturing (rate 1/2)
% RSC polynomials: 23 (feedback), 33 (feedforward) in octal.
% Max-Log-MAP iterative decoder.

clear; close all; clc;

%% Parameters
rng(0);
N_info = 1000;        % number of info bits
K_iter = 8;           % number of turbo iterations
EbN0_dB = 1.5;        % Eb/N0 in dB
rate_target = 1/2;    % after puncturing
feedback_octal = 23;  % feedback polynomial (octal)
feedforward_octal = 33; % feedforward polynomial (octal)

% Convert polynomials (octal -> binary vectors)
fb_poly = octal_to_poly_vec(feedback_octal);
ff_poly = octal_to_poly_vec(feedforward_octal);
K = length(fb_poly);      % constraint length
m = K - 1;
nStates = 2^m;

%% Build trellis for RSC (next state, parity output) for input 0/1
[NextState, ParityOut] = build_rsc_trellis(fb_poly, ff_poly);

%% Generate random info bits and interleaver
info = randi([0 1], N_info, 1);
interleaver = randperm(N_info)';

%% Turbo encoding (systematic + parity1 + parity2)
[sys, p1, p2] = turbo_encode_rsc(info, NextState, ParityOut, interleaver);

% Form rate-1/3 coded stream (systematic, p1, p2) per bit.
coded_full = zeros(3*N_info,1);
coded_full(1:3:end) = sys;
coded_full(2:3:end) = p1;
coded_full(3:3:end) = p2;

% Puncture to rate 1/2 (alternate parity transmission)
puncture_mask = create_puncture_mask(N_info); % logical mask the same size as coded_full
coded_tx = coded_full(puncture_mask);

%% BPSK mapping and AWGN channel
Eb = 1;
code_rate = 1/2;
Es = Eb * code_rate;   % energy per coded symbol (assuming systematic+parity mapping)
SNR_linear = 10^(EbN0_dB/10);
sigma2 = Eb / (2*SNR_linear*code_rate); % noise variance per real dim
sigma = sqrt(sigma2);

tx_symbols = 1 - 2*coded_tx; % BPSK: 0 -> +1, 1 -> -1
rx = tx_symbols + sigma*randn(size(tx_symbols));

% Compute channel LLRs per transmitted coded bit: Lc = 2*r/sigma^2
chanLLR_tx = (2/sigma2) * rx;

% Depuncture: expand channel LLRs to systematic,p1,p2 positions; set LLR=0 for punctured bits
chanLLR_full = zeros(length(coded_full),1);
chanLLR_full(puncture_mask) = chanLLR_tx;
% now chanLLR_full has values for systematic and parity positions; zeros for punctured

% reshape into per-bit triplets for decoder: columns [sys, p1, p2]
LLR_sys = chanLLR_full(1:3:end);
LLR_p1  = chanLLR_full(2:3:end);
LLR_p2  = chanLLR_full(3:3:end);

%% Turbo decoding (iterative exchange between two Max-Log-MAP SISOs)
% initialize apriori LLR (a-priori from other decoder) to zero
a_priori = zeros(N_info,1);       % for decoder 1 (on systematic)
a_priori_int = zeros(N_info,1);   % for decoder 2 (interleaved)

extrinsic1 = zeros(N_info,1);
extrinsic2 = zeros(N_info,1);

for iter = 1:K_iter
    % Decoder 1: uses sys and p1
    LLR_in_sys = LLR_sys;
    LLR_in_par = LLR_p1;
    % a_priori supplied from decoder2 (deinterleaved)
    % compute extrinsic using Max-Log-MAP SISO
    ext1 = maxlogmap_siso(LLR_in_sys, LLR_in_par, a_priori, NextState, ParityOut);
    extrinsic1 = ext1;
    
    % interleave extrinsic1 to feed as apriori for decoder2
    a_priori_int = extrinsic1(interleaver);
    
    % Decoder 2: uses interleaved sys and p2
    LLR_in_sys_int = LLR_sys(interleaver);
    LLR_in_par2 = LLR_p2;
    ext2_int = maxlogmap_siso(LLR_in_sys_int, LLR_in_par2, a_priori_int, NextState, ParityOut);
    extrinsic2 = ext2_int;
    
    % deinterleave extrinsic2 for next iteration apriori for decoder1
    a_priori = extrinsic2(invperm(interleaver));
    
    % a posteriori LLRs (for final decision) at decoder1:
    apriori_for_decision = a_priori + LLR_sys; % combined - but typical is LLR_sys + extrinsic + apriori
    hard = apriori_for_decision < 0;
    ber = mean(hard ~= info);
    
    fprintf('Iter %2d: BER = %.5f\n', iter, ber);
end

fprintf('Final BER after %d iterations: %.5e\n', K_iter, ber);

%% Helper functions ------------------------------------------------------

function pvec = octal_to_poly_vec(octal)
    % convert octal generator like 23 into binary vector (highest degree first)
    % octal -> decimal -> binary string
    dec = 0;
    s = num2str(octal);
    % interpret as octal digits
    for i=1:length(s)
        dec = dec*8 + (s(i)-'0');
    end
    binstr = dec2bin(dec);
    % return vector of bits MSB..LSB as numeric vector
    pvec = double(binstr) - '0';
end

function [NextState, ParityOut] = build_rsc_trellis(fb_poly, ff_poly)
    % fb_poly, ff_poly are binary vectors [g_K-1 ... g0], length K
    K = length(fb_poly);
    m = K-1;
    nStates = 2^m;
    NextState = zeros(nStates,2);  % columns for input 0 and 1
    ParityOut = zeros(nStates,2);
    for state = 0:nStates-1
        % get state bits: MSB ... LSB of shift register (length m)
        stbits = bitget(state, m:-1:1);
        for u = 0:1
            % compute feedback = xor of taps of current state where fb_poly(2:end) == 1 (excluding MSB which corresponds to input?)
            % For our simple RSC model: feedback = xor(state bits .* fb_poly(2:end))
            taps_fb = fb_poly(2:end); % length m
            fb = mod(sum(taps_fb .* stbits),2);
            v = bitxor(u, fb); % input after feedback (recursive)
            % new state is [v, stbits(1:end-1)] (shift right)
            new_stbits = [v, stbits(1:end-1)];
            new_state = bits_to_state(new_stbits);
            NextState(state+1, u+1) = new_state;
            % parity out: XOR over feedforward taps applied to [v stbits]
            taps_ff = ff_poly; % length K
            reg_with_v = [v, stbits];
            parity = mod(sum(taps_ff .* reg_with_v),2);
            ParityOut(state+1, u+1) = parity;
        end
    end
end

function s = bits_to_state(bits)
    % bits is vector [b1 b2 ... bm] MSB..LSB -> state number
    m = length(bits);
    s = 0;
    for i=1:m
        s = s*2 + bits(i);
    end
end

function [sys, p1, p2] = turbo_encode_rsc(info, NextState, ParityOut, interleaver)
    N = length(info);
    % encoder 1 (no interleaver)
    [sys, p1] = rsc_encode_stream(info, NextState, ParityOut);
    % encoder 2 uses interleaved bits
    info_int = info(interleaver);
    [~, p2int] = rsc_encode_stream(info_int, NextState, ParityOut);
    % deinterleave parity2 back to original order (parity belongs to original bit positions)
    p2 = zeros(N,1);
    p2(interleaver) = p2int;
end

function [sys, parity] = rsc_encode_stream(info, NextState, ParityOut)
    N = length(info);
    sys = info(:);
    parity = zeros(N,1);
    state = 0;
    for i=1:N
        u = info(i);
        parity(i) = ParityOut(state+1, u+1);
        state = NextState(state+1, u+1);
    end
end

function mask = create_puncture_mask(N)
    % create boolean mask for length 3*N (sys,p1,p2 repeated)
    mask = false(3*N,1);
    % always transmit systematic
    mask(1:3:end) = true;
    % alternate p1/p2
    idx = 1;
    for i=1:N
        if mod(i,2)==1
            mask(2 + 3*(i-1)) = true; % keep p1 for odd
        else
            mask(3 + 3*(i-1)) = true; % keep p2 for even
        end
    end
end

function out = invperm(p)
    % inverse permutation
    out = zeros(size(p));
    out(p) = (1:length(p))';
end

function L_ext = maxlogmap_siso(LLR_sys, LLR_par, L_a, NextState, ParityOut)
    % Max-Log-MAP SISO for an RSC code
    % LLR_sys: channel LLR for systematic bits (Nx1)
    % LLR_par: channel LLR for parity bits (Nx1) (0 for punctured positions)
    % L_a: apriori LLR (from other decoder) (Nx1)
    % returns extrinsic LLR for information bits (Nx1)
    N = length(LLR_sys);
    mStates = size(NextState,1);
    % Preallocate
    % gamma: transition metric for each time and each state-input (mStates x 2)
    % We'll compute alpha and beta in log domain (use -inf as very small)
    NEG_INF = -1e9;
    alpha = NEG_INF * ones(N+1, mStates);
    beta = NEG_INF * ones(N+1, mStates);
    alpha(1,1) = 0; % start at state 0 with prob 1
    % forward recursion: compute gamma and alpha
    for k = 1:N
        for s = 0:mStates-1
            for u = 0:1
                ns = NextState(s+1, u+1);
                % extrinsic apriori on bit u at time k: if u==1 -> L_a(k)/2 contribution
                % compute branch metric gamma (log-domain): 0.5*(systematic * Lc_sys + parity * Lc_par + apriori*something)
                % Using LLR form: branch metric = 0.5*(u*L_a(k) + u*LLR_sys(k) + parity_bit*LLR_par(k))
                parity = ParityOut(s+1, u+1);
                % metric for transition s->ns with input u
                gamma = 0.5*( (2*u-1)*L_a(k) + (2*u-1)*LLR_sys(k) + (2*parity-1)*LLR_par(k) );
                % alpha update: alpha(k+1, ns) = max(alpha(k+1,ns), alpha(k,s) + gamma)
                alpha(k+1, ns+1) = max(alpha(k+1, ns+1), alpha(k, s+1) + gamma);
            end
        end
    end
    % initialize beta at final time as zero for all states (assuming tail-biting not used)
    beta(N+1, :) = 0;
    % backwards recursion
    for k = N:-1:1
        for s = 0:mStates-1
            for u = 0:1
                ns = NextState(s+1, u+1);
                parity = ParityOut(s+1, u+1);
                gamma = 0.5*( (2*u-1)*L_a(k) + (2*u-1)*LLR_sys(k) + (2*parity-1)*LLR_par(k) );
                beta(k, s+1) = max(beta(k, s+1), beta(k+1, ns+1) + gamma);
            end
        end
    end
    % Compute extrinsic LLR for each bit: L_e(k) = max_{transitions u=1} (alpha(s)+gamma+beta(ns)) - max_{transitions u=0} (...)
    L_ext = zeros(N,1);
    for k = 1:N
        metric_u0 = NEG_INF;
        metric_u1 = NEG_INF;
        for s = 0:mStates-1
            for u = 0:1
                ns = NextState(s+1, u+1);
                parity = ParityOut(s+1, u+1);
                gamma = 0.5*( (2*u-1)*L_a(k) + (2*u-1)*LLR_sys(k) + (2*parity-1)*LLR_par(k) );
                val = alpha(k, s+1) +
