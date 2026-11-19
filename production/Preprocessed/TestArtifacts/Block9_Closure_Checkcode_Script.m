function Block9_Closure_Checkcode_Script(ProjectRoot, OutFile)
%BLOCK9_CLOSURE_CHECKCODE_SCRIPT Static analysis over all 20 Block 9 files.
%   checkcode (with -id) per file, classified by message id, plus which -all
%   resolution and shadowing check for the public entry points.

    Pkg = fullfile(ProjectRoot, '+preprocessing');
    Listing = dir(fullfile(Pkg, '*.m'));
    fid = fopen(OutFile, 'w');
    fprintf(fid, 'Block 9 closure static analysis (checkcode)\n');
    fprintf(fid, 'MATLAB: %s (%s)\n', version(), version('-release'));
    fprintf(fid, 'Generated: %s\n', char(datetime('now')));
    fprintf(fid, 'Files scanned: %d in %s\n\n', numel(Listing), Pkg);

    WarnMap = containers.Map('KeyType', 'char', 'ValueType', 'double');
    UndefinedRefs = 0;
    SyntaxErrors = 0;
    TotalMessages = 0;

    for Index = 1:numel(Listing)
        File = fullfile(Listing(Index).folder, Listing(Index).name);
        [~, BaseName] = fileparts(Listing(Index).name);
        Info = checkcode(File, '-id');
        fprintf(fid, '[%02d] %s : %d message(s)\n', ...
            Index, Listing(Index).name, numel(Info));
        TotalMessages = TotalMessages + numel(Info);
        for J = 1:numel(Info)
            MsgId = char(Info(J).id);
            MsgTxt = char(Info(J).message);
            fprintf(fid, '     L%-4d %-12s %s\n', ...
                Info(J).line, MsgId, MsgTxt);
            if isKey(WarnMap, MsgId)
                WarnMap(MsgId) = WarnMap(MsgId) + 1;
            else
                WarnMap(MsgId) = 1;
            end
            if contains(lower(MsgId), 'undefined') || ...
                    contains(lower(MsgTxt), 'undefined')
                UndefinedRefs = UndefinedRefs + 1;
            end
            if contains(lower(MsgId), 'syntax') || ...
                    contains(lower(MsgTxt), 'syntax')
                SyntaxErrors = SyntaxErrors + 1;
            end
        end
    end

    fprintf(fid, '\n=== which -all resolution / shadowing ===\n');
    PublicFns = { ...
        'preprocessing.DiscoverRuns', 'preprocessing.InspectRun', ...
        'preprocessing.PreprocessRun', 'preprocessing.GetPreprocessingReport'};
    ShadowCount = 0;
    for Index = 1:numel(PublicFns)
        W = which(PublicFns{Index}, '-all');
        if ischar(W), W = {W}; end
        fprintf(fid, '%s : %d resolved path(s)\n', ...
            PublicFns{Index}, numel(W));
        for J = 1:numel(W)
            fprintf(fid, '     %s\n', W{J});
        end
        if numel(W) > 1
            ShadowCount = ShadowCount + 1;
        end
    end

    fprintf(fid, '\n=== classified message counts (by id) ===\n');
    Ids = WarnMap.keys;
    Ids = sort(Ids);
    for Index = 1:numel(Ids)
        fprintf(fid, '%-14s %d\n', Ids{Index}, WarnMap(Ids{Index}));
    end

    fprintf(fid, '\n=== TOTALS ===\n');
    fprintf(fid, 'files_scanned=%d\n', numel(Listing));
    fprintf(fid, 'total_messages=%d\n', TotalMessages);
    fprintf(fid, 'undefined_references=%d\n', UndefinedRefs);
    fprintf(fid, 'syntax_errors=%d\n', SyntaxErrors);
    fprintf(fid, 'shadowed_public_functions=%d\n', ShadowCount);
    fprintf(fid, 'RESULT=%s\n', ...
        string(UndefinedRefs == 0 && SyntaxErrors == 0 && ShadowCount == 0));
    fclose(fid);
end
