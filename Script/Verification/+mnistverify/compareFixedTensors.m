function compareFixedTensors(actual,expected)
    %compareFixedTensors - Require exact shape, numeric type, and value
    arguments
        actual
        expected
    end
    assert(isequal(size(actual),size(expected)),'mnistverify:TensorShape','Tensor shapes differ.');
    assert(strcmp(class(actual),class(expected)),'mnistverify:TensorType','Numeric classes differ.');
    if isfi(actual)
        assert(isequal(numerictype(actual),numerictype(expected)), ...
            'mnistverify:TensorType','Fixed-point scaling or width differs.');
        actual=storedInteger(actual); expected=storedInteger(expected);
    end
    assert(all(isfinite(double(actual)),'all') && all(isfinite(double(expected)),'all'), ...
        'mnistverify:TensorValue','Nonfinite values are not accepted.');
    assert(isequal(actual,expected),'mnistverify:TensorValue','Tensor values differ.');
end
