function writeJson(filePath, value)
    %writeJson - Write UTF-8 metadata without overwriting an existing file
    %   writeJson(filePath,VALUE) creates a JSON metadata file.
    arguments
        filePath {mustBeTextScalar}
        value
    end
    assert(~isfile(filePath), 'mnistverify:AlreadyExists', ...
        'Refusing to overwrite %s.', filePath);
    fid = fopen(filePath, 'w', 'n', 'UTF-8');
    assert(fid ~= -1, 'mnistverify:WriteFailed', 'Cannot write %s.', filePath);
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '%s\n', jsonencode(value, PrettyPrint=true));
end
