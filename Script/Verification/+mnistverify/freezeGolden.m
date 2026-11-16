function bundleFolder = freezeGolden(candidateFile, baselineId)
    %freezeGolden - Freeze and pin the first qualified golden bundle
    %   bundleFolder = freezeGolden(candidateFile,baselineId) verifies a
    %   candidate, exports a standalone Simulink reference, and freezes it.
    %   Existing bundles and the active pointer are never overwritten.
    arguments
        candidateFile {mustBeTextScalar, mustBeFile}
        baselineId {mustBeTextScalar}
    end
    baselineId = string(baselineId);
    assert(~isempty(regexp(baselineId,'^[a-z][a-z0-9_]{0,39}$','once')), ...
        'mnistverify:UnsafePath', 'Use a lowercase baseline identifier.');
    projectRoot = mnistverify.root();
    goldenRoot = fullfile(projectRoot,'Data','Golden');
    bundleFolder = fullfile(goldenRoot,baselineId);
    assert(~isfolder(bundleFolder) && ~isfile(fullfile(goldenRoot,'active.json')), ...
        'mnistverify:AlreadyExists', 'A golden already exists; explicit version review is required.');
    source = load(candidateFile, 'qNet','classNames','corpus','recipe');
    qNet = source.qNet;
    classNames = source.classNames;
    qDetails = mnistverify.checkNetwork(qNet,classNames);
    corpus = source.corpus;
    expected = mnistverify.captureOutputs(qNet,corpus.Images);
    repeated = mnistverify.captureOutputs(qNet,corpus.Images);
    assert(isequaln(expected,repeated), ...
        'mnistverify:ReplayMismatch', 'Repeated inference differs.');
    buildFolder = fileparts(candidateFile);
    canonicalBuild = string(java.io.File(buildFolder).getCanonicalPath());
    canonicalResults = string(java.io.File(fullfile(projectRoot,'Results')).getCanonicalPath());
    assert(startsWith(canonicalBuild,canonicalResults+filesep,IgnoreCase=ispc), ...
        'mnistverify:UnsafePath', 'Candidate must belong to a workspace results folder.');
    stage = fullfile(buildFolder,'bundle');
    assert(~isfolder(stage), 'mnistverify:AlreadyExists', 'Staging folder already exists.');
    mkdir(stage);
    save(fullfile(stage,'network.mat'),'qNet','qDetails','classNames','-v7.3');
    save(fullfile(stage,'corpus.mat'),'corpus','-v7.3');
    save(fullfile(stage,'expected.mat'),'expected','-v7.3');
    reloaded = load(fullfile(stage,'network.mat'),'qNet','qDetails');
    replay = mnistverify.captureOutputs(reloaded.qNet,corpus.Images);
    assert(isequaln(expected,replay) && ...
        isequaln(qDetails,quantizationDetails(reloaded.qNet)), ...
        'mnistverify:ReplayMismatch', 'Serialization changed the reference.');
    copyfile(fullfile(buildFolder,'recipe.json'),fullfile(stage,'recipe.json'));
    copyfile(fullfile(buildFolder,'dataset_index.csv'),fullfile(stage,'dataset_index.csv'));
    copyfile(which('mnistverify.trainCandidate'),fullfile(stage,'training_source.m'));
    copyfile(which('mnistverify.makeCorpus'),fullfile(stage,'corpus_source.m'));
    modelName = "golden_" + baselineId;
    assert(~bdIsLoaded(modelName), 'mnistverify:ModelLoaded', 'Golden model name already loaded.');
    exportNetworkToSimulink(qNet, ModelName=modelName, ModelPath=stage, ...
        SaveNetworkInModelWorkspace=true, OpenSystem=false, SampleTime='1');
    close_system(modelName,0);
    assert(isfile(fullfile(stage,modelName+'.slx')), ...
        'mnistverify:ExportFailed', 'Standalone Simulink export is missing.');
    mnistverify.writeJson(fullfile(stage,'boundary_contract.json'), struct( ...
        SchemaVersion=1, InputSize=[28 28 1], InputType="uint8", ...
        Normalization="inside_network", FrameInputFormat="SSCB", ...
        StreamOrder="row_pixel_channel", ClassOrder=classNames, ...
        FcBoundary="fc", ProbabilityBoundary="softmax", ...
        ExpectedArrayOrder="batch_class", Comparison="exact_no_reordering_no_truncation", ...
        LibraryInterfaceStatus="to_be_qualified_in_stage_2"));
    files = dir(stage);
    files = files(~[files.isdir]);
    payload = repmat(struct(Name="",SHA256="",Bytes=0),numel(files),1);
    for k = 1:numel(files)
        payload(k) = struct(Name=string(files(k).name), ...
            SHA256=mnistverify.sha256(fullfile(stage,files(k).name)), Bytes=files(k).bytes);
    end
    manifest = struct(SchemaVersion=1, BaselineId=baselineId, Release=string(version('-release')), ...
        CreatedUTC=string(datetime('now',TimeZone='UTC',Format="yyyy-MM-dd'T'HH:mm:ssXXX")), ...
        Origin=string(source.recipe.Origin), CandidateSHA256=mnistverify.sha256(candidateFile), ...
        Files=payload, SimulinkModel=modelName+'.slx', ...
        Checks=struct(RepeatedInference=true, SerializationReplay=true, ...
        SimulinkExport=true, SimulinkNumericalEquivalence=false, ...
        CCodeGeneration=false, HDLCodeGeneration=false), CorpusCount=size(corpus.Images,4));
    mnistverify.writeJson(fullfile(stage,'manifest.json'),manifest);
    manifestHash = mnistverify.sha256(fullfile(stage,'manifest.json'));
    mnistverify.verifyBundle(stage,manifestHash);
    if ~isfolder(goldenRoot), mkdir(goldenRoot); end
    % Both locations are within the workspace; no recursive delete is used.
    movefile(stage,bundleFolder);
    mnistverify.verifyBundle(bundleFolder,manifestHash);
    mnistverify.writeJson(fullfile(goldenRoot,'active.json'),struct( ...
        SchemaVersion=1, BaselineId=baselineId, ManifestSHA256=manifestHash));
    fprintf('Frozen golden: %s\nManifest SHA-256: %s\n',bundleFolder,manifestHash);
end
