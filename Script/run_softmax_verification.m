function report = run_softmax_verification()
    %run_softmax_verification - Check normalized HDL scores against golden
    %   REPORT = run_softmax_verification() simulates 26 fixed images and
    %   checks every class score against the frozen quantized network.
    %   It also checks result timing and rejects a misaligned reference.
    %   Results are saved under Results without changing model parameters.
    %
    %   See also run_verification, initialize_hdl_model

    root = fileparts(fileparts(mfilename('fullpath')));
    previousPath = path;
    restorePath = onCleanup(@() path(previousPath));
    addpath(fullfile(root,'Script','Verification'),fullfile(root,'Model'));
    mdl = 'quantizedNetwork_hdl';
    source = fullfile(root,'Model',[mdl '.slx']);
    if ~bdIsLoaded(mdl), open_system(source); end
    assert(strcmpi(get_param(mdl,'FileName'),source), ...
        'SoftmaxCheck:ModelShadowed','A different model is loaded.');
    assert(strcmp(get_param(mdl,'Dirty'),'off'), ...
        'SoftmaxCheck:UnsavedModel','Save the model before verification.');
    golden = mnistverify.loadGolden(root);
    folder = fullfile(root,'Results', ...
        ['softmax_verification_' char(datetime('now',Format='yyyyMMdd_HHmmss_SSS'))]);
    mkdir(folder);
    oldConfig = Simulink.fileGenControl('getConfig');
    restoreConfig = onCleanup(@() Simulink.fileGenControl('setConfig','config',oldConfig));
    Simulink.fileGenControl('set','CacheFolder',fullfile(root,'Work','cache'), ...
        'CodeGenFolder',fullfile(root,'Work','codegen'),'createDir',true);
    frameCount = size(golden.Corpus.Images,4);
    % Remove the singleton channel dimension for the frame input port.
    frames = timeseries(reshape(golden.Corpus.Images,28,28,frameCount), ...
        (0:frameCount-1).');
    in = Simulink.SimulationInput(mdl);
    in = in.setVariable('softmaxVerificationFrames',frames);
    inputBlock = Simulink.ID.getFullName([mdl ':86']);
    in = in.setBlockParameter(inputBlock,'VariableName','softmaxVerificationFrames');
    in = in.setBlockParameter(inputBlock,'Interpolate','off');
    in = in.setBlockParameter(inputBlock,'OutputAfterFinalValue','Holding final value');
    % Offset the reference by one frame to exercise the mismatch display.
    align = find_system(mdl,'SearchDepth',1,'Name','Align_Golden_Scores');
    assert(isscalar(align),'SoftmaxCheck:Structure','Missing reference alignment.');
    negativeInput = in.setBlockParameter(align{1},'DelayLength','63');
    negativeInput = negativeInput.setModelParameter('StopTime','3.1');
    negative = mnistverify.p0Simulate(negativeInput, ...
        fullfile(folder,'misalignment_simulation.txt'));
    negativeValid = logical(negative.score_valid.Data(:));
    negativeMatches = logical(negative.scores_match.Data(:));
    negativeErrors = negative.score_max_abs_error.Data(:);
    assert(any(~negativeMatches(negativeValid)) && any(negativeErrors(negativeValid)>0), ...
        'SoftmaxCheck:NegativeControl','The comparison failed to detect misalignment.');

    in = in.setModelParameter('StopTime',sprintf('%.17g',frameCount+0.1));
    out = mnistverify.p0Simulate(in,fullfile(folder,'simulation.txt'));
    valid = logical(out.score_valid.Data(:));
    validIndices = find(valid);
    time = out.score_valid.Time(valid);
    assert(numel(validIndices)==frameCount && all(diff(validIndices)>1), ...
        'SoftmaxCheck:ValidCount','Expected one valid pulse per input frame.');
    expectedTime = (0:frameCount-1).'+1203/1140;
    assert(max(abs(time-expectedTime))<1e-10, ...
        'SoftmaxCheck:Timing','Frame alignment or result latency changed.');
    hdlAll = rows(out.hdl_scores);
    goldenAll = rows(out.golden_scores);
    hdl = hdlAll(valid,:);
    embedded = goldenAll(valid,:);
    mnistverify.compareFixedTensors(hdl,golden.Expected.Softmax);
    mnistverify.compareFixedTensors(embedded,golden.Expected.Softmax);
    errors = out.score_max_abs_error.Data(:);
    matches = logical(out.scores_match.Data(:));
    assert(all(errors(valid)==0) && all(matches(valid)), ...
        'SoftmaxCheck:Comparison','The in-model comparison did not pass.');
    assert(~any(matches(1:validIndices(1)-1)), ...
        'SoftmaxCheck:Startup','Match must remain false before the first result.');
    changes = any(diff(double(hdlAll),1,1)~=0,2) | ...
        any(diff(double(goldenAll),1,1)~=0,2);
    assert(~any(changes & ~valid(2:end)), ...
        'SoftmaxCheck:Hold','Displayed scores changed outside result-valid.');
    scoreSums = sum(double(hdl),2);
    assert(all(double(hdl)>=0 & double(hdl)<=1,'all') && ...
        all(abs(scoreSums-1)<=10/256), ...
        'SoftmaxCheck:Normalization','Scores exceed quantized probability bounds.');

    perFrame = table(golden.Corpus.Names,time,max(abs(double(hdl)- ...
        double(golden.Expected.Softmax)),[],2),scoreSums, ...
        VariableNames={'Case','ResultTime','MaxAbsError','ScoreSum'});
    writetable(perFrame,fullfile(folder,'per_frame.csv'));
    report = struct(Passed=true,Frames=frameCount,ClassScores=frameCount*10, ...
        MaxAbsError=0,BitExact=true,OutputType='ufix8_En8', ...
        ResultDelayCycles=1203,PixelPeriod=1/1140, ...
        ScoreSumRange=[min(scoreSums),max(scoreSums)], ...
        MisalignmentDetected=true,GoldenId=golden.Id, ...
        GoldenManifestSHA256=golden.ManifestSHA256, ...
        ModelSHA256=mnistverify.sha256(source),Folder=string(folder));
    save(fullfile(folder,'scores.mat'),'hdl','embedded','time','perFrame','report');
    mnistverify.writeJson(fullfile(folder,'report.json'),report);
    fprintf('PASS: %d frames, %d scores, bit-exact golden match.\n%s\n', ...
        frameCount,frameCount*10,folder);
end

function data = rows(signal)
    if signal.IsTimeFirst
        data = reshape(signal.Data,numel(signal.Time),[]);
    else
        data = reshape(signal.Data,[],numel(signal.Time)).';
    end
end
