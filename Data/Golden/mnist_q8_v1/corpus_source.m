function corpus = makeCorpus(validation, classNames)
    %makeCorpus - Build fixed representative and boundary input images
    %   CORPUS = makeCorpus(VALIDATION,classNames) selects two validation
    %   images per class and adds six deterministic diagnostic images.
    arguments
        validation
        classNames (:,1) string
    end
    pixels = zeros(28, 28, 1, 26, 'uint8');
    names = strings(26,1);
    labels = repmat("diagnostic",26,1);
    sources = strings(26,1);
    for k = 1:10
        idx = find(string(validation.Labels) == classNames(k), 2);
        assert(numel(idx) == 2, 'mnistverify:Corpus', 'Missing class images.');
        for j = 1:2
            n = 2*(k-1) + j;
            value = readimage(validation, idx(j));
            assert(isa(value,'uint8') && isequal(size(value),[28 28]), ...
                'mnistverify:Corpus', 'Expected uint8 28-by-28 images.');
            pixels(:,:,1,n) = value;
            names(n) = "digit_" + classNames(k) + "_" + j;
            labels(n) = classNames(k);
            [~, stem, ext] = fileparts(validation.Files{idx(j)});
            sources(n) = classNames(k) + '/' + string(stem) + ext;
        end
    end
    names(21:26) = ["zeros";"full255";"ramp";"impulse";"checkerboard";"synthetic5"];
    pixels(:,:,1,22) = 255;
    pixels(:,:,1,23) = uint8(mod(reshape(0:783,28,28).',256));
    pixels(14,14,1,24) = 255;
    [row,col] = ndgrid(1:28,1:28);
    pixels(:,:,1,25) = uint8(mod(row+col,2)*255);
    five = zeros(28,28,'uint8');
    five(6:7,8:20)=255; five(7:14,8:9)=255; five(14:15,8:20)=255;
    five(15:22,19:20)=255; five(22:23,8:20)=255;
    pixels(:,:,1,26) = five;
    corpus = struct(Images=pixels, Names=names, Labels=labels, Sources=sources, ...
        InputContract="uint8 [28 28 1 N], unnormalized; normalization is inside qNet");
end
