function startMNISTProject()
    %startMNISTProject - Open the MNIST HDL model without changing its data
    project = currentProject;
    modelFile = fullfile(project.RootFolder,'Model','quantizedNetwork_hdl.slx');
    if bdIsLoaded('quantizedNetwork_hdl')
        actual = get_param('quantizedNetwork_hdl','FileName');
        assert(strcmpi(actual,modelFile),'MNISTProject:ModelShadowed', ...
            'A different quantizedNetwork_hdl model is already loaded.');
    end
    open_system(modelFile);
    dut = find_system('quantizedNetwork_hdl','SearchDepth',1,'Name','HDL_MNIST_STREAM_MULTCH');
    if isscalar(dut)
        open_system(dut{1});
    end
end
