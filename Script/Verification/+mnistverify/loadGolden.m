function golden = loadGolden(projectRoot)
    %loadGolden - Load the active reference only after integrity verification
    %   GOLDEN = loadGolden() loads the pinned reference in this workspace.
    %   GOLDEN = loadGolden(projectRoot) uses another verification workspace.
    %   This function never trains, writes files, or reads base variables.
    arguments
        projectRoot {mustBeTextScalar, mustBeFolder} = mnistverify.root()
    end
    pointerPath = fullfile(projectRoot, 'Data','Golden', 'active.json');
    assert(isfile(pointerPath), 'mnistverify:NoGolden', 'No frozen golden is active.');
    pointer = jsondecode(fileread(pointerPath));
    assert(isfield(pointer,'SchemaVersion') && pointer.SchemaVersion==1 && ...
        isfield(pointer,'BaselineId') && isfield(pointer,'ManifestSHA256'), ...
        'mnistverify:Schema', 'Invalid active golden pointer.');
    baselineId = string(pointer.BaselineId);
    assert(~isempty(regexp(baselineId,'^[a-z][a-z0-9_]{0,39}$','once')), ...
        'mnistverify:UnsafePath', 'Invalid golden identifier.');
    folder = fullfile(projectRoot, 'Data','Golden', baselineId);
    assert(isfolder(folder), 'mnistverify:MissingFile', 'Golden bundle is missing.');
    manifest = mnistverify.verifyBundle(folder, pointer.ManifestSHA256);
    assert(strcmp(manifest.BaselineId,baselineId), ...
        'mnistverify:Schema', 'Pointer and manifest identify different baselines.');
    assert(strcmp(manifest.Release,version('-release')), ...
        'mnistverify:ReleaseMismatch', 'Requalify this golden before changing MATLAB releases.');
    recipe = jsondecode(fileread(fullfile(folder,'recipe.json')));
    assert(strcmp(recipe.MATLABVersion,version), ...
        'mnistverify:ReleaseMismatch', 'Requalify this golden before changing the MATLAB build.');
    network = load(fullfile(folder,'network.mat'),'qNet','qDetails','classNames');
    freshDetails = mnistverify.checkNetwork(network.qNet, network.classNames);
    assert(isequaln(freshDetails,network.qDetails), ...
        'mnistverify:DetailsMismatch', 'Stored details do not belong to the frozen network.');
    inputs = load(fullfile(folder,'corpus.mat'),'corpus');
    outputs = load(fullfile(folder,'expected.mat'),'expected');
    golden = struct(Id=baselineId, Folder=string(folder), ...
        ManifestSHA256=string(pointer.ManifestSHA256), Manifest=manifest, ...
        Network=network.qNet, Quantization=freshDetails, Classes=network.classNames, ...
        Corpus=inputs.corpus, Expected=outputs.expected);
end
