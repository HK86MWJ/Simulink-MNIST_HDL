function out = p0Simulate(in, logPath)
    %p0Simulate - Run configured simulation and retain its diagnostics
    arguments
        in (1,1) Simulink.SimulationInput
        logPath {mustBeTextScalar}
    end
    [transcript,out]=evalc('sim(in)');
    fid=fopen(logPath,'w','n','UTF-8');
    assert(fid~=-1,'mnistverify:WriteFailed','Cannot save simulation diagnostics.');
    cleanup=onCleanup(@() fclose(fid));
    fprintf(fid,'%s',transcript);
end
