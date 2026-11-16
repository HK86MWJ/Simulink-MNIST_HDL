function results = run_verification()
    %run_verification - Run framework and frozen-reference qualification
    %   RESULTS = run_verification() verifies the active golden and runs
    %   MATLAB unit tests. Reports are saved in a new results subfolder.
    %   This stage does not claim HDL or Simulink numerical equivalence.

    projectRoot=fileparts(fileparts(mfilename('fullpath')));
    previousPath = path;
    cleanup = onCleanup(@() path(previousPath));
    addpath(fullfile(projectRoot,'Script','Verification'));
    golden = mnistverify.loadGolden(projectRoot);
    runId = "qualification_" + string(datetime('now',Format='yyyyMMdd_HHmmss_SSS'));
    outputFolder = fullfile(projectRoot,'Results',runId);
    assert(~isfolder(outputFolder),'mnistverify:AlreadyExists','Run folder already exists.');
    mkdir(outputFolder);
    % Run the portable tests shipped with this repository. Local historical
    % tests can depend on archived results and are intentionally excluded.
    suite = [testsuite(fullfile(projectRoot,'Test','framework','GoldenIntegrityTest.m')), ...
        testsuite(fullfile(projectRoot,'Test','golden','GoldenReplayTest.m'))];
    runner = matlab.unittest.TestRunner.withTextOutput;
    runner.addPlugin(matlab.unittest.plugins.XMLPlugin.producingJUnitFormat( ...
        fullfile(outputFolder,'junit.xml')));
    codeFiles = [dir(fullfile(projectRoot,'Script','Verification','**','*.m')); ...
        dir(fullfile(projectRoot,'Test','framework','GoldenIntegrityTest.m')); ...
        dir(fullfile(projectRoot,'Test','golden','GoldenReplayTest.m')); ...
        dir(string(mfilename('fullpath'))+".m")];
    codeManifest = repmat(struct(File="",SHA256=""),numel(codeFiles),1);
    for k = 1:numel(codeFiles)
        filePath = fullfile(codeFiles(k).folder,codeFiles(k).name);
        relativePath = string(filePath(numel(projectRoot)+2:end));
        codeManifest(k) = struct(File=replace(relativePath,'\','/'), ...
            SHA256=mnistverify.sha256(filePath));
    end
    mnistverify.writeJson(fullfile(outputFolder,'verification_code.json'),codeManifest);
    results = runner.run(suite);
    mnistverify.verifyBundle(golden.Folder,golden.ManifestSHA256);
    save(fullfile(outputFolder,'test_results.mat'),'results');
    summary = struct(SchemaVersion=1, Stage="S1_and_stream_foundations", ...
        GoldenId=golden.Id, ManifestSHA256=golden.ManifestSHA256, ...
        Release=string(version('-release')), Passed=all([results.Passed]), ...
        TestCount=numel(results), FailureCount=nnz([results.Failed]), ...
        IncompleteCount=nnz([results.Incomplete]), ...
        HDLModelSHA256=mnistverify.sha256(fullfile(projectRoot,'Model','quantizedNetwork_hdl.slx')), ...
        SimulinkEquivalence="not_run", CCodeGeneration="not_run", HDLCodeGeneration="not_run");
    mnistverify.writeJson(fullfile(outputFolder,'summary.json'),summary);
    fprintf('Qualification report: %s\n',outputFolder);
    assert(summary.Passed,'mnistverify:QualificationFailed','Golden qualification failed.');
end
