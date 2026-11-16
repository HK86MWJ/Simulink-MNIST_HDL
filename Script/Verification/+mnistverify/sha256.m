function digest = sha256(filePath)
    %SHA256 - Compute the SHA-256 of a file without changing it
    %   DIGEST = SHA256(filePath) returns a lowercase hexadecimal string.
    arguments
        filePath {mustBeTextScalar, mustBeFile}
    end
    fid = fopen(filePath, 'rb');
    assert(fid ~= -1, 'mnistverify:ReadFailed', 'Cannot open %s.', filePath);
    cleanup = onCleanup(@() fclose(fid));
    engine = java.security.MessageDigest.getInstance('SHA-256');
    while ~feof(fid)
        bytes = fread(fid, 1048576, '*uint8');
        engine.update(bytes);
    end
    bytes = typecast(engine.digest(), 'uint8');
    digest = string(lower(reshape(dec2hex(bytes, 2).', 1, [])));
end
