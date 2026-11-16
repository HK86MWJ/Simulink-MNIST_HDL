classdef GoldenReplayTest < matlab.unittest.TestCase
    %GoldenReplayTest - Qualify the active frozen network and input corpus
    properties
        Golden
    end
    methods (TestClassSetup)
        function loadReference(testCase)
            testCase.Golden = mnistverify.loadGolden();
        end
    end
    methods (Test)
        function repeatInferenceIsExact(testCase)
            actual = mnistverify.captureOutputs(testCase.Golden.Network, ...
                testCase.Golden.Corpus.Images);
            testCase.verifyTrue(isequal(actual,testCase.Golden.Expected), ...
                'Fixed-point values, array shape and types must remain exact.');
            testCase.verifyEqual(numerictype(actual.FcLogits), ...
                numerictype(testCase.Golden.Expected.FcLogits));
            testCase.verifyEqual(numerictype(actual.Softmax), ...
                numerictype(testCase.Golden.Expected.Softmax));
            testCase.verifyEqual(storedInteger(actual.FcLogits), ...
                storedInteger(testCase.Golden.Expected.FcLogits));
            testCase.verifyEqual(storedInteger(actual.Softmax), ...
                storedInteger(testCase.Golden.Expected.Softmax));
        end
        function corpusCoversAllClasses(testCase)
            testCase.verifyEqual(testCase.Golden.Corpus.Labels(1:20), ...
                repelem(string((0:9).'),2));
            testCase.verifyEqual(numel(unique(testCase.Golden.Corpus.Names)),26);
            testCase.verifySize(testCase.Golden.Corpus.Images,[28 28 1 26]);
        end
        function networkAndDetailsAgree(testCase)
            actual = quantizationDetails(testCase.Golden.Network);
            testCase.verifyTrue(isequaln(actual,testCase.Golden.Quantization));
        end
        function outputsKeepFixedPointTypes(testCase)
            testCase.verifyTrue(isfi(testCase.Golden.Expected.FcLogits));
            testCase.verifyTrue(isfi(testCase.Golden.Expected.Softmax));
            testCase.verifySize(testCase.Golden.Expected.FcLogits,[26 10]);
            testCase.verifySize(testCase.Golden.Expected.Softmax,[26 10]);
        end
        function rejectsWrongInputShape(testCase)
            testCase.verifyError(@() mnistverify.captureOutputs(testCase.Golden.Network, ...
                zeros(27,28,'uint8')),'mnistverify:InputShape');
        end
        function refusesReplacingActiveGolden(testCase)
            testCase.verifyError(@() mnistverify.freezeGolden( ...
                fullfile(testCase.Golden.Folder,'network.mat'),testCase.Golden.Id), ...
                'mnistverify:AlreadyExists');
        end
        function standaloneSimulinkReferenceCompiles(testCase)
            modelName = testCase.prepareModel();
            workspace = get_param(modelName,'ModelWorkspace');
            referenceNetwork = workspace.getVariable('qNet');
            testCase.verifyTrue(isequaln(quantizationDetails(referenceNetwork), ...
                testCase.Golden.Quantization));
            set_param(modelName,'SimulationCommand','update');
            testCase.verifyEqual(get_param(modelName,'Dirty'),'off');
        end
    end
    methods (Access=private)
        function modelName = prepareModel(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            previous = Simulink.fileGenControl('getConfig');
            testCase.addTeardown(@() Simulink.fileGenControl('setConfig','config',previous));
            Simulink.fileGenControl('set', 'CacheFolder',fullfile(fixture.Folder,'cache'), ...
                'CodeGenFolder',fullfile(fixture.Folder,'codegen'),'createDir',true);
            [~,modelName] = fileparts(testCase.Golden.Manifest.SimulinkModel);
            modelPath = fullfile(testCase.Golden.Folder,testCase.Golden.Manifest.SimulinkModel);
            if bdIsLoaded(modelName)
                testCase.assertEqual(string(get_param(modelName,'FileName')),string(modelPath));
                testCase.assertEqual(get_param(modelName,'Dirty'),'off');
            else
                load_system(modelPath);
                testCase.addTeardown(@() close_system(modelName,0));
            end
        end
    end
end
