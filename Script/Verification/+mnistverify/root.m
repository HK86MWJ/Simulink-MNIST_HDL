function folder = root()
    %ROOT - Locate this verification workspace
    %   FOLDER = ROOT() returns the workspace containing this package.
    folder = string(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
end
