%%% Generate HDLNN fixed-point parameters from quantizedNetwork_4ch/qNet.
%
% Run ExportQuantizedNetworkToSimulinkExample.mlx before this script.
% The golden reference is quantizedNetwork_4ch, which is backed by qNet.
% BatchNorm is folded into qNet learnables, so do not use net.Layers for
% HDL parameters.

if ~exist("qNet", "var")
    error("HDLNN:MissingQNet", ...
        "qNet is required. Run ExportQuantizedNetworkToSimulinkExample.mlx before HDLNN_setup.m.");
end

if ~exist("qDetails", "var")
    qDetails = quantizationDetails(qNet);
end

ql = qDetails.QuantizedLearnables;

W1_CONV_FI = squeeze(getQuantizedLearnable(ql, "conv_1", "Weights"));
W1_BIAS_FI = squeeze(getQuantizedLearnable(ql, "conv_1", "Bias"));
W1_CONV_FI = rotateConvKernelSpatial180(W1_CONV_FI);

w2_conv_fi_pre = getQuantizedLearnable(ql, "conv_2", "Weights");
W2_BIAS_FI = squeeze(getQuantizedLearnable(ql, "conv_2", "Bias"));
w2_conv_fi_pre = rotateConvKernelSpatial180(w2_conv_fi_pre);

% Each Conv2 output-channel branch sums four per-input-channel paths. The
% branch bias must be injected once, not once per input channel.
W2_BIAS_BRANCH1_FI = makeBranchBias(W2_BIAS_FI, 1);
W2_BIAS_BRANCH2_FI = makeBranchBias(W2_BIAS_FI, 2);
W2_BIAS_BRANCH3_FI = makeBranchBias(W2_BIAS_FI, 3);
W2_BIAS_BRANCH4_FI = makeBranchBias(W2_BIAS_FI, 4);

W2_CONV_FI = cell(1,4);
for k = 1:4
    W2_CONV_FI{k} = w2_conv_fi_pre(:,:,:,k);   % 3x3x4
end

W_FC_FI = getQuantizedLearnable(ql, "fc", "Weights");  % 10x484
B_FC_FI = getQuantizedLearnable(ql, "fc", "Bias");     % 10x1
W_FC_TRANSPOSE_FI = W_FC_FI.';                         % 484x10
B_FC_TRANSPOSE_FI = B_FC_FI.';                         % 1x10

% HDL_FullyConnect receives a 4-channel feature vector in row-major spatial
% stream order. The reference fullyConnectedLayer flattens 11x11x4 in
% MATLAB column-major order, so convert the row-major stream coordinate to
% the corresponding qNet weight-column index.
W_FC_BY_PIXEL_FI = fi(zeros(10, 4, 121), ...
    numerictype(W_FC_FI), fimath(W_FC_FI));
fcRows = repelem(1:11, 11);
fcCols = repmat(1:11, 1, 11);
for p = 1:121
    spatialIndex = fcRows(p) + (fcCols(p)-1)*11;
    W_FC_BY_PIXEL_FI(:,:,p) = W_FC_FI(:, spatialIndex + (0:3)*121);
end

function value = getQuantizedLearnable(learnables, layerName, parameterName)
layer = string(learnables.Layer);
parameter = string(learnables.Parameter);
idx = layer == layerName & parameter == parameterName;

if nnz(idx) ~= 1
    error("HDLNN:MissingQuantizedLearnable", ...
        "Expected exactly one learnable for %s/%s, found %d.", ...
        layerName, parameterName, nnz(idx));
end

value = learnables.Value{idx};
end

function weightsOut = rotateConvKernelSpatial180(weightsIn)
% The HDL convolution datapath presents each 3x3 window in the opposite
% spatial order from quantizedNetwork_4ch/conv_*.
weightsOut = weightsIn;

switch ndims(weightsIn)
    case 2
        weightsOut = rot90(weightsIn, 2);
    case 3
        for c = 1:size(weightsIn, 3)
            weightsOut(:,:,c) = rot90(weightsIn(:,:,c), 2);
        end
    case 4
        for c = 1:size(weightsIn, 3)
            for k = 1:size(weightsIn, 4)
                weightsOut(:,:,c,k) = rot90(weightsIn(:,:,c,k), 2);
            end
        end
    otherwise
        error("HDLNN:UnsupportedConvWeightRank", ...
            "Expected 2-D, 3-D, or 4-D convolution weights, got %d-D.", ...
            ndims(weightsIn));
end
end

function branchBias = makeBranchBias(bias, index)
branchBias = fi(zeros(4, 1), numerictype(bias), fimath(bias));
branchBias(1) = bias(index);
end
