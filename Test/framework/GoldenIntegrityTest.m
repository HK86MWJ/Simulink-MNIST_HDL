classdef GoldenIntegrityTest < matlab.unittest.TestCase
    %GoldenIntegrityTest - Qualify integrity checks independently of training
    properties
        Folder
        Hash
    end
    methods (TestMethodSetup)
        function createBundle(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.Folder = string(fixture.Folder);
            testCase.writeBytes('payload.bin',uint8('abc'));
            testCase.Hash = testCase.writeManifest('payload.bin',1);
        end
    end
    methods (Test)
        function knownSha256(testCase)
            actual = mnistverify.sha256(fullfile(testCase.Folder,'payload.bin'));
            testCase.verifyEqual(actual, ...
                "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
        end
        function acceptsIntactBundle(testCase)
            manifest = mnistverify.verifyBundle(testCase.Folder,testCase.Hash);
            testCase.verifyEqual(manifest.SchemaVersion,1);
        end
        function detectsPayloadTampering(testCase)
            testCase.writeBytes('payload.bin',uint8('abd'));
            testCase.verifyError(@() mnistverify.verifyBundle(testCase.Folder,testCase.Hash), ...
                'mnistverify:Integrity');
        end
        function detectsManifestTampering(testCase)
            testCase.writeBytes('manifest.json',uint8('{}'));
            testCase.verifyError(@() mnistverify.verifyBundle(testCase.Folder,testCase.Hash), ...
                'mnistverify:Integrity');
        end
        function rejectsMissingPayload(testCase)
            testCase.Hash = testCase.writeManifest('missing.bin',1);
            testCase.verifyError(@() mnistverify.verifyBundle(testCase.Folder,testCase.Hash), ...
                'mnistverify:MissingFile');
        end
        function rejectsUnregisteredPayload(testCase)
            testCase.writeBytes('extra.bin',uint8(42));
            testCase.verifyError(@() mnistverify.verifyBundle(testCase.Folder,testCase.Hash), ...
                'mnistverify:UnregisteredFile');
        end
        function rejectsPathTraversal(testCase)
            testCase.Hash = testCase.writeManifest('../payload.bin',1);
            testCase.verifyError(@() mnistverify.verifyBundle(testCase.Folder,testCase.Hash), ...
                'mnistverify:UnsafePath');
        end
        function rejectsUnsupportedSchema(testCase)
            testCase.Hash = testCase.writeManifest('payload.bin',2);
            testCase.verifyError(@() mnistverify.verifyBundle(testCase.Folder,testCase.Hash), ...
                'mnistverify:Schema');
        end
        function preventsMetadataOverwrite(testCase)
            testCase.verifyError(@() mnistverify.writeJson( ...
                fullfile(testCase.Folder,'manifest.json'),struct()),'mnistverify:AlreadyExists');
        end
        function missingGoldenDoesNotTrain(testCase)
            testCase.verifyError(@() mnistverify.loadGolden(testCase.Folder),'mnistverify:NoGolden');
            testCase.verifyFalse(isfolder(fullfile(testCase.Folder,'results')));
        end
    end
    methods (Access=private)
        function writeBytes(testCase,name,bytes)
            fid = fopen(fullfile(testCase.Folder,name),'wb');
            cleanup = onCleanup(@() fclose(fid));
            fwrite(fid,bytes,'uint8');
        end
        function hash = writeManifest(testCase,name,schema)
            manifest = struct(SchemaVersion=schema, Files=struct(Name=name, ...
                SHA256=mnistverify.sha256(fullfile(testCase.Folder,'payload.bin'))));
            testCase.writeBytes('manifest.json',unicode2native(jsonencode(manifest),'UTF-8'));
            hash = mnistverify.sha256(fullfile(testCase.Folder,'manifest.json'));
        end
    end
end
