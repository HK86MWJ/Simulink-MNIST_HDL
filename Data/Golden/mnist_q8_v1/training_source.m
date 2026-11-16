function candidateFile = trainCandidate()
    %trainCandidate - Train a new, explicitly versioned MNIST baseline
    %   candidateFile = trainCandidate() trains on the MathWorks digit
    %   dataset using a fixed seed and CPU, then saves an unfrozen candidate.
    %   It does not replace or activate an existing golden baseline.
    %
    %   See also mnistverify.freezeGolden, mnistverify.loadGolden

    projectRoot = mnistverify.root();
    runId = "golden_build_" + string(datetime('now', Format='yyyyMMdd_HHmmss_SSS'));
    runFolder = fullfile(projectRoot, 'results', runId);
    assert(~isfolder(runFolder), 'mnistverify:AlreadyExists', 'Run already exists.');
    mkdir(runFolder);
    oldRng = rng;
    cleanup = onCleanup(@() rng(oldRng));
    rng(20261111, 'twister');
    dataRoot = fullfile(matlabroot, 'toolbox', 'nnet', 'nndemos', ...
        'nndatasets', 'DigitDataset');
    assert(isfolder(dataRoot), 'mnistverify:MissingDataset', ...
        'The MathWorks DigitDataset is required.');
    images = imageDatastore(dataRoot, IncludeSubfolders=true, LabelSource='foldernames');
    [sortedFiles, order] = sort(string(images.Files));
    images = subset(images, order);
    [training, validation] = splitEachLabel(images, 0.75, 'randomized');
    calibration = splitEachLabel(training, 0.1, 'randomized');
    classNames = string(categories(training.Labels));
    assert(isequal(classNames(:), string((0:9).')), ...
        'mnistverify:Classes', 'Expected class order 0 through 9.');

    relative = erase(replace(sortedFiles, '\', '/'), replace(string(dataRoot), '\', '/') + '/');
    split = repmat("validation", numel(sortedFiles), 1);
    split(ismember(sortedFiles, string(training.Files))) = "training";
    isCalibration = ismember(sortedFiles, string(calibration.Files));
    hashes = strings(numel(sortedFiles), 1);
    for k = 1:numel(sortedFiles)
        hashes(k) = mnistverify.sha256(sortedFiles(k));
    end
    datasetIndex = table(relative, string(images.Labels), split, isCalibration, hashes, ...
        VariableNames={'File','Label','Split','Calibration','SHA256'});
    writetable(datasetIndex, fullfile(runFolder, 'dataset_index.csv'));
    recipe = struct(SchemaVersion=1, Seed=20261111, RNG="twister", ...
        Dataset="MathWorks DigitDataset bundled with MATLAB", ...
        TrainingCount=numel(training.Files), ValidationCount=numel(validation.Files), ...
        CalibrationCount=numel(calibration.Files), ExecutionEnvironment="cpu", ...
        Solver="adam", InitialLearnRate=0.01, MaxEpochs=5, MiniBatchSize=128, ...
        Shuffle="every-epoch", ValidationFrequency=30, ...
        Release=string(version('-release')), MATLABVersion=string(version), ...
        Origin="new_training_not_the_20260908_network");
    mnistverify.writeJson(fullfile(runFolder, 'recipe.json'), recipe);

    layers = [
        imageInputLayer([28 28 1], Normalization='rescale-zero-one', Name='imageinput')
        convolution2dLayer(3, 4, Name='conv_1')
        batchNormalizationLayer(Name='batchnorm_1')
        reluLayer(Name='relu_1')
        maxPooling2dLayer(2, Stride=2, Name='maxpool')
        convolution2dLayer(3, 4, Name='conv_2')
        batchNormalizationLayer(Name='batchnorm_2')
        reluLayer(Name='relu_2')
        fullyConnectedLayer(10, Name='fc')
        softmaxLayer(Name='softmax')];
    options = trainingOptions('adam', InitialLearnRate=0.01, MaxEpochs=5, ...
        MiniBatchSize=128, Shuffle='every-epoch', ValidationData=validation, ...
        ValidationFrequency=30, Verbose=false, Plots='none', ExecutionEnvironment='cpu');
    fprintf('Training %d images on CPU; run: %s\n', numel(training.Files), runFolder);
    net = trainnet(training, layers, 'crossentropy', options);
    save(fullfile(runFolder, 'trained_network.mat'), 'net', 'recipe', 'classNames', '-v7.3');
    fprintf('Calibrating %d training images and quantizing.\n', numel(calibration.Files));
    quantizer = dlquantizer(net, ExecutionEnvironment='MATLAB');
    prepareNetwork(quantizer);
    calibrationResults = calibrate(quantizer, calibration);
    qNet = quantize(quantizer);
    qDetails = quantizationDetails(qNet);
    corpus = mnistverify.makeCorpus(validation, classNames);
    candidateFile = fullfile(runFolder, 'candidate.mat');
    save(candidateFile, 'qNet', 'qDetails', 'net', 'recipe', 'classNames', ...
        'corpus', 'calibrationResults', '-v7.3');
    fprintf('Candidate saved: %s\n', candidateFile);
end
