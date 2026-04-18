classdef FormattingPipeline
    %FORMATTINGPIPELINE Core text and file formatting helpers.

    methods (Static)
        function formatFileNoEditor(file, outFile, varargin)
            MBeautifier.FormattingPipeline.requireExistingFile(file);

            if nargin < 2 || isempty(outFile)
                outFile = file;
            end

            text = fileread(file);
            configuration = MBeautifier.ConfigurationResolver.resolveForFile(file, varargin{:});
            text = MBeautifier.FormattingPipeline.formatText(text, configuration);
            MBeautifier.FormattingPipeline.writeTextFile(outFile, text);
        end

        function formatFiles(directory, fileFilter, recurse, editor, varargin)
            MBeautifier.FormattingPipeline.requireExistingDirectory(directory);

            files = MBeautifier.FormattingPipeline.collectFiles(directory, fileFilter, recurse);
            for iF = 1:numel(files)
                file = fullfile(files(iF).folder, files(iF).name);
                MBeautifier.FormattingPipeline.formatFileInPlace(file, editor, varargin{:});
            end
        end

        function result = checkFile(file, useEditor, varargin)
            result = MBeautifier.FormattingPipeline.inspectFile(file, useEditor, 'check', varargin{:});
        end

        function result = diffFile(file, useEditor, varargin)
            result = MBeautifier.FormattingPipeline.inspectFile(file, useEditor, 'diff', varargin{:});
        end

        function result = checkFiles(directory, fileFilter, recurse, editor, varargin)
            result = MBeautifier.FormattingPipeline.inspectFiles(directory, fileFilter, recurse, editor, 'check', varargin{:});
        end

        function result = diffFiles(directory, fileFilter, recurse, editor, varargin)
            result = MBeautifier.FormattingPipeline.inspectFiles(directory, fileFilter, recurse, editor, 'diff', varargin{:});
        end

        function formattedText = formatText(text, configuration)
            % Format and indent plain text using the active configuration.
            formatter = MBeautifier.MFormatter(configuration);
            indenter = MBeautifier.MIndenter(configuration);
            formattedText = formatter.performFormatting(text);
            formattedText = indenter.performIndenting(formattedText);
        end

        function formattedText = formatTextWithResolvedConfiguration(text, varargin)
            configuration = MBeautifier.ConfigurationResolver.resolveForText(varargin{:});
            formattedText = MBeautifier.FormattingPipeline.formatText(text, configuration);
        end

        function requireExistingFile(file)
            if exist(file, 'file') ~= 2
                error('MBeautifier:FileDoesNotExist', ...
                    'The file "%s" does not exist. Provide an existing MATLAB file to format.', file);
            end
        end

        function requireExistingDirectory(directory)
            if exist(directory, 'dir') ~= 7
                error('MBeautifier:DirectoryDoesNotExist', ...
                    'The directory "%s" does not exist. Provide an existing directory to format.', directory);
            end
        end

        function writeTextFile(path, text)
            [fid, errorMessage] = fopen(path, 'wt');
            if fid == -1
                error('MBeautifier:OutputFileNotWritable', ...
                    'Unable to open "%s" for writing. %s', path, errorMessage);
            end
            fileCloser = onCleanup(@() fclose(fid));
            fprintf(fid, '%s', text);
        end

        function configuration = getConfiguration()
            % Load and cache the active formatter configuration.
            configuration = MBeautifier.ConfigurationResolver.defaultConfiguration();
        end
    end

    methods (Static, Access = private)
        function result = inspectFiles(directory, fileFilter, recurse, editor, mode, varargin)
            MBeautifier.FormattingPipeline.requireExistingDirectory(directory);
            files = MBeautifier.FormattingPipeline.collectFiles(directory, fileFilter, recurse);

            if isempty(files)
                details = MBeautifier.FormattingPipeline.emptyFileResultArray();
            else
                details = repmat(MBeautifier.FormattingPipeline.emptyFileResult(), 1, numel(files));
            end

            for iF = 1:numel(files)
                file = fullfile(files(iF).folder, files(iF).name);
                try
                    details(iF) = MBeautifier.FormattingPipeline.inspectFile(file, editor, mode, varargin{:});
                catch ME
                    details(iF) = MBeautifier.FormattingPipeline.createFailedFileResult(file, ME);
                end
            end

            result = MBeautifier.FormattingPipeline.buildBatchResult(details);
        end

        function result = inspectFile(file, useEditor, mode, varargin)
            MBeautifier.FormattingPipeline.requireExistingFile(file);

            originalText = fileread(file);
            configuration = MBeautifier.ConfigurationResolver.resolveForFile(file, varargin{:});
            if useEditor
                formattedText = MBeautifier.EditorApp.previewFormattedFile(file, configuration);
            else
                formattedText = MBeautifier.FormattingPipeline.formatText(originalText, configuration);
            end

            diffSummary = MBeautifier.FormattingPipeline.buildDiffSummary(originalText, formattedText);
            changed = diffSummary.lineChanges > 0;
            status = 'unchanged';
            if changed
                status = 'changed';
            end

            result = struct( ...
                'path', file, ...
                'status', status, ...
                'changed', changed, ...
                'message', MBeautifier.FormattingPipeline.messageForInspection(mode, changed), ...
                'diffSummary', diffSummary);
        end

        function files = collectFiles(directory, fileFilter, recurse)
            if recurse
                directory = fullfile(directory, '**');
            end

            files = dir(fullfile(directory, fileFilter));
            if ~isempty(files)
                files = files(~[files.isdir]);
            end
        end

        function formatFileInPlace(file, useEditor, varargin)
            if useEditor
                MBeautifier.EditorApp.formatFile(file, file, varargin{:});
            else
                MBeautifier.FormattingPipeline.formatFileNoEditor(file, file, varargin{:});
            end
        end

        function result = buildBatchResult(details)
            if isempty(details)
                changedCount = 0;
                unchangedCount = 0;
                failedCount = 0;
            else
                statuses = {details.status};
                changedCount = nnz(strcmp(statuses, 'changed'));
                unchangedCount = nnz(strcmp(statuses, 'unchanged'));
                failedCount = nnz(strcmp(statuses, 'failed'));
            end

            result = struct( ...
                'filesScanned', numel(details), ...
                'filesChanged', changedCount, ...
                'filesUnchanged', unchangedCount, ...
                'filesFailed', failedCount, ...
                'details', details);
        end

        function result = createFailedFileResult(file, ME)
            result = struct( ...
                'path', file, ...
                'status', 'failed', ...
                'changed', false, ...
                'message', ME.message, ...
                'diffSummary', MBeautifier.FormattingPipeline.emptyDiffSummary());
        end

        function diffSummary = buildDiffSummary(originalText, formattedText)
            originalText = MBeautifier.FormattingPipeline.normalizeText(originalText);
            formattedText = MBeautifier.FormattingPipeline.normalizeText(formattedText);

            originalLines = regexp(originalText, '\n', 'split');
            formattedLines = regexp(formattedText, '\n', 'split');
            maxLineCount = max(numel(originalLines), numel(formattedLines));
            changedLineNumbers = [];
            previewLines = cell(1, min(3, maxLineCount));
            previewCount = 0;

            for iLine = 1:maxLineCount
                originalLine = MBeautifier.FormattingPipeline.lineAt(originalLines, iLine);
                formattedLine = MBeautifier.FormattingPipeline.lineAt(formattedLines, iLine);

                if ~strcmp(originalLine, formattedLine)
                    changedLineNumbers(end+1) = iLine; %#ok<AGROW>
                    if previewCount < 3
                        previewCount = previewCount + 1;
                        previewLines{previewCount} = sprintf('L%d: "%s" -> "%s"', ...
                            iLine, originalLine, formattedLine);
                    end
                end
            end

            firstChangeLine = 0;
            if ~isempty(changedLineNumbers)
                firstChangeLine = changedLineNumbers(1);
            end

            preview = '';
            if previewCount > 0
                preview = strjoin(previewLines(1:previewCount), newline);
            end

            diffSummary = struct( ...
                'lineChanges', numel(changedLineNumbers), ...
                'firstChangeLine', firstChangeLine, ...
                'preview', preview);
        end

        function text = normalizeText(text)
            text = strrep(text, sprintf('\r'), '');
        end

        function line = lineAt(lines, index)
            line = '';
            if index <= numel(lines)
                line = lines{index};
            end
        end

        function message = messageForInspection(mode, changed)
            if changed
                if strcmp(mode, 'diff')
                    message = 'Formatting would change the file. Diff summary available.';
                else
                    message = 'Formatting would change the file.';
                end
            else
                message = 'The file already matches the resolved formatting rules.';
            end
        end

        function result = emptyFileResult()
            result = struct( ...
                'path', '', ...
                'status', 'unchanged', ...
                'changed', false, ...
                'message', '', ...
                'diffSummary', MBeautifier.FormattingPipeline.emptyDiffSummary());
        end

        function results = emptyFileResultArray()
            results = repmat(MBeautifier.FormattingPipeline.emptyFileResult(), 1, 0);
        end

        function diffSummary = emptyDiffSummary()
            diffSummary = struct( ...
                'lineChanges', 0, ...
                'firstChangeLine', 0, ...
                'preview', '');
        end
    end
end
