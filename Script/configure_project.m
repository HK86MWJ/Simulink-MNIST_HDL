function project = configure_project()
    %configure_project - Configure the reproducible MNIST HDL project
    root = fileparts(fileparts(mfilename('fullpath')));
    project = matlab.project.rootProject;
    if isempty(project), project = openProject(root); end
    assert(strcmpi(project.RootFolder,root),'MNISTProject:WrongProject', ...
        'Open this MNIST HDL project before configuring it.');
    project.Name = 'MNIST_HDL';
    project.Summary = 'Streaming MNIST CNN with fixed-point golden-score verification';
    project.ProjectStartupFolder = root;
    for folder = ["Script","Script/Verification","Model","Test"]
        addPath(project,fullfile(root,folder));
    end
    files = strip(readlines(fullfile(root,'resources','repository_files.txt')));
    files = files(strlength(files)>0 & ~startsWith(files,'#'));
    for k=1:numel(files)
        file = fullfile(root,files(k));
        assert(isfile(file),'MNISTProject:MissingFile','Missing project asset: %s',files(k));
        if ~endsWith(files(k),'.prj')
            addFile(project,file);
        end
    end
    addFile(project,fullfile(root,'resources','repository_files.txt'));
    cacheFolder = fullfile(root,'Work','cache');
    codeFolder = fullfile(root,'Work','codegen');
    if ~isfolder(cacheFolder), mkdir(cacheFolder); end
    if ~isfolder(codeFolder), mkdir(codeFolder); end
    project.SimulinkCacheFolder = cacheFolder;
    project.SimulinkCodeGenFolder = codeFolder;
    project.DependencyCacheFile = fullfile(root,'Work','dependencies.graphml');
    addStartupFile(project,fullfile(root,'Script','startMNISTProject.m'));
    shortcuts = ["Model/quantizedNetwork_hdl.slx","README.md", ...
        "Script/run_softmax_verification.m","Script/run_verification.m", ...
        "Script/initialize_hdl_model.m"];
    names = ["MNIST HDL model","Getting started","Verify Softmax scores", ...
        "Verify golden integrity","Reload golden parameters"];
    groups = ["Model","Docs","Verification","Verification","Setup"];
    for k=1:numel(shortcuts)
        file = fullfile(root,shortcuts(k));
        existing = project.Shortcuts;
        match = find(strcmpi(string({existing.File}),file),1);
        if isempty(match), shortcut = addShortcut(project,file);
        else, shortcut = existing(match); end
        shortcut.Name = names(k);
        shortcut.Group = groups(k);
    end
end
