function manifest = verifyBundle(bundleFolder, manifestHash)
    %verifyBundle - Verify a pinned manifest and every registered payload
    %   MANIFEST = verifyBundle(bundleFolder,manifestHash) rejects missing,
    %   changed, unregistered, or path-escaping bundle files before loading.
    arguments
        bundleFolder {mustBeTextScalar, mustBeFolder}
        manifestHash {mustBeTextScalar}
    end
    manifestPath = fullfile(bundleFolder, 'manifest.json');
    assert(isfile(manifestPath), 'mnistverify:MissingFile', 'Missing manifest.json.');
    assert(strcmp(mnistverify.sha256(manifestPath), manifestHash), ...
        'mnistverify:Integrity', 'Manifest differs from its pinned SHA-256.');
    manifest = jsondecode(fileread(manifestPath));
    assert(isfield(manifest,'SchemaVersion') && manifest.SchemaVersion==1, ...
        'mnistverify:Schema', 'Unsupported golden manifest schema.');
    assert(isfield(manifest,'Files') && isstruct(manifest.Files) && ...
        ~isempty(manifest.Files) && all(isfield(manifest.Files,{'Name','SHA256'})), ...
        'mnistverify:Schema', 'Manifest has no payload files.');
    names = string({manifest.Files.Name});
    assert(numel(unique(names))==numel(names), ...
        'mnistverify:Schema', 'Duplicate payload paths in manifest.');
    for k = 1:numel(names)
        assert(~isempty(regexp(string(manifest.Files(k).SHA256),'^[a-f0-9]{64}$','once')), ...
            'mnistverify:Schema', 'Payload digest is not a SHA-256 value.');
        assert(~isempty(regexp(names(k),'^[A-Za-z0-9][A-Za-z0-9_.-]*$','once')) ...
            && names(k)~="manifest.json", ...
            'mnistverify:UnsafePath', 'Payload names must be simple filenames.');
        filePath = fullfile(bundleFolder, names(k));
        assert(isfile(filePath), 'mnistverify:MissingFile', 'Missing %s.', names(k));
        assert(strcmp(mnistverify.sha256(filePath), manifest.Files(k).SHA256), ...
            'mnistverify:Integrity', 'Payload changed: %s.', names(k));
    end
    listing = dir(bundleFolder);
    actual = string({listing(~[listing.isdir]).name});
    subfolders = string({listing([listing.isdir]).name});
    assert(all(ismember(subfolders,[".",".."])) && ...
        isequal(sort(actual), sort([names,"manifest.json"])), ...
        'mnistverify:UnregisteredFile', 'Bundle contains unregistered files or folders.');
end
