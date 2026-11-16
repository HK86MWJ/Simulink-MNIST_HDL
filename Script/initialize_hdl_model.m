function receipt = initialize_hdl_model()
    %initialize_hdl_model - Load verified golden parameters into the model
    %   RECEIPT = initialize_hdl_model() initializes the open HDL model's
    %   Model Workspace. It neither retrains nor saves the model file.
    root=fileparts(fileparts(mfilename('fullpath')));
    previousPath=path;
    cleanup=onCleanup(@() path(previousPath));
    addpath(fullfile(root,'Script','Verification'));
    golden=mnistverify.loadGolden(root);
    parameters=mnistverify.buildHdlParameters(golden);
    model='quantizedNetwork_hdl';
    modelFile=fullfile(root,'Model',[model '.slx']);
    if bdIsLoaded(model)
        assert(strcmpi(get_param(model,'FileName'),modelFile), ...
            'mnistverify:WrongModel','A different model with this name is open.');
    else
        open_system(modelFile);
    end
    workspace=get_param(model,'ModelWorkspace');
    assert(strcmp(workspace.DataSource,'Model File'), ...
        'mnistverify:WorkspaceSource','Review the model workspace data source before initializing.');
    names=fieldnames(parameters);
    for k=1:numel(names)
        workspace.assignin(names{k},parameters.(names{k}));
    end
    receipt=struct(Model=string(modelFile),GoldenId=golden.Id, ...
        ManifestSHA256=golden.ManifestSHA256,VariableCount=numel(names), ...
        CoefficientMappingVerified=true,Storage="Model Workspace (in memory)",ModelSaved=false);
    fprintf('Initialized %s from %s: %d verified model-workspace variables.\n', ...
        model,golden.Id,numel(names));
end
