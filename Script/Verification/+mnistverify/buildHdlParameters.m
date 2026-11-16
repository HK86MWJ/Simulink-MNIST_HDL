function parameters = buildHdlParameters(golden)
    %buildHdlParameters - Build the legacy HDL adapter from a pinned qNet
    %   PARAMETERS = buildHdlParameters(GOLDEN) derives fresh quantization
    %   details and returns coefficients and legacy model setup variables.
    %   No base workspace variables are read or written.
    arguments
        golden (1,1) struct
    end
    qNet=golden.Network;
    qDetails=quantizationDetails(qNet); %#ok<NASGU>
    % The legacy scripts run in this function workspace only. They supply
    % the retained model's diagnostic patterns as well as its coefficients.
    run(fullfile(mnistverify.root(),'Script','HDLNN_setup.m'));
    names={ ...
        'qNet','qDetails','W1_CONV_FI','W1_BIAS_FI','W2_CONV_FI','W2_BIAS_FI', ...
        'W2_BIAS_BRANCH1_FI','W2_BIAS_BRANCH2_FI','W2_BIAS_BRANCH3_FI','W2_BIAS_BRANCH4_FI', ...
        'W_FC_FI','B_FC_FI','W_FC_TRANSPOSE_FI','B_FC_TRANSPOSE_FI','W_FC_BY_PIXEL_FI', ...
        'ROI_after_CONV2D_1ST','ROI_after_CONV2D_2ND', ...
        'img_in_tp5x5','img_in_tp6x6','img_in_tp8x8','img_in_tp28x28','img_tp28x28_s5', ...
        'conv3x3_param1','conv3x3_param2','conv3x3_param3','LUT3D_TableData'};
    parameters=struct();
    for k=1:numel(names)
        parameters.(names{k})=eval(names{k});
    end
    parameters.GOLDEN_ID=golden.Id;
    parameters.GOLDEN_MANIFEST_SHA256=golden.ManifestSHA256;
    parameters.NORMALIZATION_RANGE=double(golden.Network.Layers(1).Max-golden.Network.Layers(1).Min);
    assert(parameters.NORMALIZATION_RANGE>0,'mnistverify:Normalization','Normalization range must be positive.');
    mnistverify.validateHdlParameters(parameters,golden);
end
