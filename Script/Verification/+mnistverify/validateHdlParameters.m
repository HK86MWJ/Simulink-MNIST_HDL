function validateHdlParameters(parameters,golden)
    %validateHdlParameters - Check every coefficient against its source
    arguments
        parameters (1,1) struct
        golden (1,1) struct
    end
    learnables=quantizationDetails(golden.Network).QuantizedLearnables;
    getValue=@(layer,parameter) learnables.Value{ ...
        string(learnables.Layer)==layer & string(learnables.Parameter)==parameter};
    w1=getValue("conv_1","Weights");
    w2=getValue("conv_2","Weights");
    b1=getValue("conv_1","Bias");
    b2=getValue("conv_2","Bias");
    wf=getValue("fc","Weights");
    bf=getValue("fc","Bias");
    assertFi(parameters.W1_BIAS_FI,reshape(b1,4,1));
    assertFi(parameters.W2_BIAS_FI,reshape(b2,4,1));
    assertFi(parameters.W_FC_FI,wf);
    assertFi(parameters.B_FC_FI,bf);
    assertFi(parameters.W_FC_TRANSPOSE_FI,wf.');
    assertFi(parameters.B_FC_TRANSPOSE_FI,bf.');
    % Explicit coordinate lookup is independent of the rotation helper.
    for output=1:4
        for row=1:3
            for col=1:3
                assertFi(parameters.W1_CONV_FI(row,col,output),w1(4-row,4-col,1,output));
                for input=1:4
                    assertFi(parameters.W2_CONV_FI{output}(row,col,input),w2(4-row,4-col,input,output));
                end
            end
        end
        branch=parameters.(sprintf('W2_BIAS_BRANCH%d_FI',output));
        assertFi(branch(1),b2(output));
        assert(all(storedInteger(branch(2:4))==0),'mnistverify:CoefficientMismatch','Bias repeated across branches.');
    end
    for row=1:11
        for col=1:11
            pixel=(row-1)*11+col;
            for channel=1:4
                column=row+11*(col-1)+121*(channel-1);
                assertFi(parameters.W_FC_BY_PIXEL_FI(:,channel,pixel),wf(:,column));
            end
        end
    end
    assert(isequaln(parameters.qDetails,quantizationDetails(parameters.qNet)), ...
        'mnistverify:CoefficientMismatch','qNet and qDetails differ.');
    assert(isequaln(parameters.qDetails,quantizationDetails(golden.Network)), ...
        'mnistverify:CoefficientMismatch','HDL reference is not the pinned golden.');
end

function assertFi(actual,expected)
    assert(isfi(actual) && isfi(expected) && isequal(numerictype(actual),numerictype(expected)) && ...
        isequal(size(actual),size(expected)) && isequal(storedInteger(actual),storedInteger(expected)), ...
        'mnistverify:CoefficientMismatch','Coefficient value, type, or shape differs from the golden.');
end
