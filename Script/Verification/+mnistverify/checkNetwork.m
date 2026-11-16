function details = checkNetwork(qNet, classNames)
    %checkNetwork - Validate the architecture and quantized learnables
    %   DETAILS = checkNetwork(qNet,classNames) rejects an unquantized or
    %   structurally incompatible reference and derives fresh details.
    arguments
        qNet (1,1) dlnetwork
        classNames (:,1) string
    end
    expectedNames = ["imageinput";"conv_1";"relu_1";"maxpool"; ...
        "conv_2";"relu_2";"fc";"softmax"];
    assert(isequal(string({qNet.Layers.Name}).', expectedNames), ...
        'mnistverify:Architecture', 'Unexpected layer sequence after quantization.');
    assert(isequal(classNames, string((0:9).')), ...
        'mnistverify:Classes', 'The class mapping must be explicitly 0 through 9.');
    assert(isequal(qNet.Layers(1).InputSize, [28 28 1]), ...
        'mnistverify:Architecture', 'Expected 28-by-28 grayscale inputs.');
    inputLayer = qNet.Layers(1);
    assert(strcmp(inputLayer.Normalization,'rescale-zero-one') && ...
        isequal(inputLayer.Min,0) && isequal(inputLayer.Max,255), ...
        'mnistverify:Normalization', 'Expected in-network scaling from [0,255] to [0,1].');
    details = quantizationDetails(qNet);
    assert(isfield(details,'QuantizedLearnables'), ...
        'mnistverify:Unquantized', 'Network has no quantized learnables.');
    learnables = details.QuantizedLearnables;
    layers = ["conv_1","conv_1","conv_2","conv_2","fc","fc"];
    parameters = ["Weights","Bias","Weights","Bias","Weights","Bias"];
    shapes = {[3 3 1 4],[1 1 4 1],[3 3 4 4],[1 1 4 1],[10 484 1 1],[10 1 1 1]};
    assert(height(learnables)==6, 'mnistverify:Architecture', ...
        'Expected exactly six quantized weight and bias tensors.');
    for k = 1:6
        selected = string(learnables.Layer)==layers(k) & ...
            string(learnables.Parameter)==parameters(k);
        assert(nnz(selected)==1, 'mnistverify:Architecture', 'Missing learnable tensor.');
        value = learnables.Value{selected};
        actualShape = [size(value,1),size(value,2),size(value,3),size(value,4)];
        assert(isfi(value) && isequal(actualShape,shapes{k}), ...
            'mnistverify:Unquantized', 'Learnable tensor has an unexpected type or size.');
        assert(all(isfinite(double(value)), 'all'), ...
            'mnistverify:Nonfinite', 'Learnables must be finite.');
    end
end
