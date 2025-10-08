%% turbo_full_23_31_srrc_maxlogmap_modified.m
clear; clc; close all;

%% ========================
%% Functions
%% ========================
function pvec = octal_to_poly_vec(octal)
    decval = base2dec(num2str(octal),8);
    bstr = dec2bin(decval);
    pvec = zeros(1,length(bstr));
    for i=1:length(bstr)
        pvec(i) = str2double(bstr(i));
    end
end

function [sys, parity] = rsc_encode_stream(u, fb_poly, ff_poly)
    N = length(u);
    Kpoly = length(fb_poly);
    mem = Kpoly-1;
    sr = zeros(1,mem);
    sys = u;
    parity = zeros(1,N);
    for k=1:N
        in_vec = [u(k) sr];
        fb = mod(sum(fb_poly .* in_vec),2);
        parity(k) = mod(sum(ff_poly .* [fb sr]),2);
        sr = [fb sr(1:end-1)];
    end
end

function h = srrc_pulse(alpha,sps,span)
    t=(-span*sps:span*sps)/sps;
    h=zeros(size(t));
    for ii=1:length(t)
        ti=t(ii);
        if abs(ti)<1e-12
            h(ii)=1-alpha+(4*alpha/pi);
        elseif abs(abs(ti)-1/(4*alpha))<1e-12
            h(ii)=(alpha/sqrt(2))*((1+2/pi)*sin(pi/(4*alpha))+(1-2/pi)*cos(pi/(4*alpha)));
        else
            num=sin(pi*ti*(1-alpha))+4*alpha*ti.*cos(pi*ti*(1+alpha));
            den=pi*ti.*(1-(4*alpha*ti).^2);
            h(ii)=num/den;
        end
    end
    h=h/sqrt(sum(h.^2));
end

%% ========================
%% Parameters / Options
%% ========================
K = 64;                % info bits
use_alt1010 = false;
run_decoder = true;
EbN0_dB = 6;             % increase SNR
nIter = 3;               % more turbo iterations

feedback_octal    = 23;
feedforward_octal = 31;

alpha = 0.5; sps=8; span=8; NFFT=8192;

%% ========================
%% Prepare polynomials
%% ========================
fb_poly = octal_to_poly_vec(feedback_octal);
ff_poly = octal_to_poly_vec(feedforward_octal);
Kpoly = max(length(fb_poly), length(ff_poly));
if length(fb_poly)<Kpoly, fb_poly=[zeros(1,Kpoly-length(fb_poly)) fb_poly]; end
if length(ff_poly)<Kpoly, ff_poly=[zeros(1,Kpoly-length(ff_poly)) ff_poly]; end
mem = Kpoly-1;

%% ========================
%% Input bits
%% ========================
if use_alt1010
    data_in = repmat([1 0],1,K/2);
else
    data_in = randi([0 1],1,K);
end

%% ========================
%% Random interleaver
%% ========================
pi = randperm(K);

%% ========================
%% Turbo encoding
%% ========================
[s1,p1] = rsc_encode_stream(data_in, fb_poly, ff_poly);
u_int = data_in(pi);
[s2,p2] = rsc_encode_stream(u_int, fb_poly, ff_poly);

%% ========================
%% Puncturing to rate 1/2
%% ========================
mask_p1 = mod(1:K,2)==1;
mask_p2 = ~mask_p1;
punctured_bits = zeros(1,2*K);
for k=1:K
    sysbit = s1(k);
    if mask_p1(k), par = p1(k); else par = p2(k); end
    punctured_bits(2*k-1)=sysbit;
    punctured_bits(2*k)=par;
end

%% ========================
%% SRRC pulse shaping & spectrum
%% ========================
tx_symbols = 2*punctured_bits-1;
h = srrc_pulse(alpha,sps,span);
tx_ups = upsample(tx_symbols,sps);
tx_shaped = conv(tx_ups,h,'same');

% Spectrum
spec = fftshift(abs(fft(tx_shaped,NFFT)));
spec_db = 20*log10(spec/max(spec));
f_axis = linspace(-0.5,0.5,NFFT);
figure; plot(f_axis,spec_db,'LineWidth',1.3); grid on;
xlabel('Normalized Frequency'); ylabel('Magnitude (dB)');
title('SRRC-shaped punctured turbo');

%% ========================
%% Max-Log-MAP Turbo Decoder
%% ========================
if run_decoder
    EbN0 = 10^(EbN0_dB/10); R = K/length(punctured_bits); N0 = 1/(EbN0*R); sigma=sqrt(N0/2); Lc=2/N0;
    tx_sys_sym = 1-2*s1; tx_p1_sym=1-2*p1; tx_p2_sym=1-2*p2;
    rx_sys = tx_sys_sym + sigma*randn(1,K);
    rx_p1  = tx_p1_sym  + sigma*randn(1,K);
    rx_p2  = tx_p2_sym  + sigma*randn(1,K);

    L_sys = Lc*rx_sys;
    L_p1 = zeros(1,K); L_p2 = zeros(1,K);
    L_p1(mask_p1) = Lc*rx_p1(mask_p1);
    L_p2(mask_p2) = Lc*rx_p2(mask_p2);

    % Precompute trellis
    nStates = 2^mem; nextState=zeros(nStates,2); parityBit=zeros(nStates,2);
    for st=0:nStates-1
        sr = bitget(st,mem:-1:1);
        for u=0:1
            fb = mod(sum(fb_poly.*[u sr]),2);
            parityBit(st+1,u+1) = mod(sum(ff_poly.*[fb sr]),2);
            new_sr = [fb sr(1:end-1)];
            nextState(st+1,u+1) = bi2de(new_sr,'left-msb');
        end
    end

    alphaMat = -inf(nStates,K+1); alphaMat(1,1)=0;
    betaMat  = -inf(nStates,K+1); betaMat(:,K+1)=0;
    gammaMat = -inf(nStates,2,K);
    La = zeros(1,K);

    % Run turbo iterations
    for iter=1:nIter
        Lext1 = maxlogmap_decoder(L_sys,L_p1,La,nextState,parityBit,alphaMat,betaMat,gammaMat);
        La2 = 0.1*Lext1(pi); % properly scale extrinsic info
        L_sys_int = L_sys(pi); L_p2_int = L_p2(pi);
        Lext2 = maxlogmap_decoder(L_sys_int,L_p2_int,La2,nextState,parityBit,alphaMat,betaMat,gammaMat);
        La = zeros(1,K); La(pi) = 0.1*Lext2;
    end

    L_total = L_sys + La;
    u_hat = (L_total<0);
    nErr = sum(data_in~=u_hat);
    fprintf('Decoding result: Errors = %d / %d\n', nErr,K);
end
