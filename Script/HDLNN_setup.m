%%% Generate required parameters for HDLNN.
%
% Workflow:
% 1. Run ExportQuantizedNetworkToSimulinkExample.mlx.
% 2. Run this setup script.
%
% The HDL golden reference is quantizedNetwork_4ch/qNet. BatchNorm is
% folded into qNet learnables, so HDL parameters are generated from
% qDetails.QuantizedLearnables by HDLNN_quantizedLearnables_setup.m.

%% Test Patterns

% 5x5
img_tp5x5_double = [1 2 3 4 5; 6 7 8 9 10; 11 12 13 14 15; 16 17 18 19 20; 21 22 23 24 25];
img_tp5x5 = uint8(img_tp5x5_double);
img_in_tp5x5.time = 0;
img_in_tp5x5.signals.values = img_tp5x5;
img_in_tp5x5.signals.dimensions = [5 5];

% 6x6
img_tp6x6_double = [1 2 3 4 5 6; 7 8 9 10 11 12; 13 14 15 16 17 18; 19 20 21 22 23 24; 25 26 27 28 29 30; 31 32 33 34 35 36];
img_tp6x6 = uint8(img_tp6x6_double);
img_in_tp6x6.time = 0;
img_in_tp6x6.signals.values = img_tp6x6;
img_in_tp6x6.signals.dimensions = [6 6];

% 8x8
img_tp8x8_double = [1 2 3 4 5 6 7 8 ; 11 12 13 15 18 19 25 21; 53 23 44 52 26 49 32 39; 76 35 74 32 16 91 12 22; 16 24 44 25 18 4 25 21; 14 12 35 65 118 32 33 21; 3 63 88 31 30 63 24 41; 51 20 43 39 23 47 20 5];
img_tp8x8 = uint8(img_tp8x8_double);
img_in_tp8x8.time = 0;
img_in_tp8x8.signals.values = img_tp8x8;
img_in_tp8x8.signals.dimensions = [8 8];

% 28x28
img_tp28x28_double = reshape(1:784, 28, 28).';
img_tp28x28 = uint8(img_tp28x28_double);
img_in_tp28x28.time = 0;
img_in_tp28x28.signals.values = img_tp28x28;
img_in_tp28x28.signals.dimensions = [28 28];

% 28x28 handwritten-like "5" pattern.
img_tp28x28_s5_uint8 = zeros(28,28,'uint8');
img_tp28x28_s5_uint8(6:7, 8:20) = 255;
img_tp28x28_s5_uint8(7:14, 8:9) = 255;
img_tp28x28_s5_uint8(14:15, 8:20) = 255;
img_tp28x28_s5_uint8(15:22, 19:20) = 255;
img_tp28x28_s5_uint8(22:23, 8:20) = 255;

img_tp28x28_s5.time = 0;
img_tp28x28_s5.signals.values = img_tp28x28_s5_uint8;
img_tp28x28_s5.signals.dimensions = [28 28];

%% RAM Contents Generate

conv3x3_param1_double = [1 2 3; 4 5 6; 7 8 9];
conv3x3_param1 = uint8(conv3x3_param1_double);
conv3x3_param2 = uint8([1 2 3; 4 5 6; 7 8 9]);
conv3x3_param3 = uint8([1 2 3; 4 5 6; 7 8 9]);

tmp_result = conv2(img_tp5x5_double, conv3x3_param1_double, 'valid');

%% Hyper Parameters for HDL

run(fullfile(fileparts(mfilename('fullpath')), 'HDLNN_quantizedLearnables_setup.m'));

%% Table

H = 3;
W = 3;
N = 4;

LUT3D_TableData = uint8(zeros(H, W, N));
for k = 1:N
    LUT3D_TableData(:,:,k) = uint8(k * ones(H, W));
end

%% Frame Size

ROI_after_CONV2D_1ST = [1 2 26 26];
ROI_after_CONV2D_2ND = [1 2 11 11];
