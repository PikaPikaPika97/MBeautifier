classdef EditorApp
    %EDITORAPP MATLAB Editor integration helpers for MBeautifier.

    methods (Static)
        function formatFile(file, outFile, varargin)
            MBeautifier.FormattingPipeline.requireExistingFile(file);

            if nargin < 2
                outFile = [];
            end

            configuration = MBeautifier.ConfigurationResolver.resolveForFile(file, varargin{:});
            isOpen = MBeautifier.DesktopAdapter.isDocumentOpen(file);
            document = MBeautifier.DesktopAdapter.openDocument(file);
            MBeautifier.DesktopAdapter.setText(document, ...
                MBeautifier.FormattingPipeline.formatText(MBeautifier.DesktopAdapter.getText(document), configuration));

            MBeautifier.EditorApp.indentPage(document, configuration);

            if ~isempty(outFile)
                if exist(outFile, 'file')
                    fileattrib(outFile, '+w');
                end

                MBeautifier.DesktopAdapter.saveDocumentAs(document, outFile);
                if ~isOpen
                    MBeautifier.DesktopAdapter.closeDocument(document);
                end
            end
        end

        function formattedText = previewFormattedFile(file, configuration)
            MBeautifier.FormattingPipeline.requireExistingFile(file);

            [~, name, ext] = fileparts(file);
            tempDirectory = tempname();
            mkdir(tempDirectory);
            cleanupDirectory = onCleanup(@() MBeautifier.EditorApp.deleteDirectoryIfPossible(tempDirectory));
            tempPath = fullfile(tempDirectory, [name, ext]);
            copyfile(file, tempPath);

            document = MBeautifier.DesktopAdapter.openDocument(tempPath);
            cleanupDocument = onCleanup(@() MBeautifier.EditorApp.closeDocumentIfPossible(document));

            MBeautifier.DesktopAdapter.setText(document, ...
                MBeautifier.FormattingPipeline.formatText(MBeautifier.DesktopAdapter.getText(document), configuration));
            MBeautifier.EditorApp.indentPage(document, configuration);
            formattedText = MBeautifier.DesktopAdapter.getText(document);
        end

        function formatEditorSelection(doSave)
            currentEditorPage = MBeautifier.EditorApp.requireActiveEditorPage();
            currentSelection = MBeautifier.DesktopAdapter.getSelection(currentEditorPage);
            selectedText = MBeautifier.DesktopAdapter.getSelectedText(currentEditorPage);

            selectionRequest = MBeautifier.EditorSelectionFormatting.plan( ...
                MBeautifier.DesktopAdapter.getText(currentEditorPage), currentSelection, selectedText);

            if nargin == 0
                doSave = false;
            end

            configuration = MBeautifier.ConfigurationResolver.resolveForEditorDocument(currentEditorPage);
            formattedSource = MBeautifier.FormattingPipeline.formatText(selectionRequest.CodeToFormat, configuration);

            MBeautifier.DesktopAdapter.setText(currentEditorPage, ...
                MBeautifier.EditorSelectionFormatting.rebuild(selectionRequest, formattedSource));
            MBeautifier.EditorApp.indentPage(currentEditorPage, configuration);
            if ~isempty(selectionRequest.RestorePosition)
                MBeautifier.DesktopAdapter.goToPositionInLine( ...
                    currentEditorPage, selectionRequest.RestorePosition(1), selectionRequest.RestorePosition(2));
            end
            MBeautifier.DesktopAdapter.setSelection(currentEditorPage, selectionRequest.ExpandedSelection);
            MBeautifier.DesktopAdapter.activateDocument(currentEditorPage);

            if doSave
                MBeautifier.EditorApp.saveEditorPageIfPossible(currentEditorPage);
            end
        end

        function formatCurrentEditorPage(doSave)
            currentEditorPage = MBeautifier.EditorApp.requireActiveEditorPage();

            if nargin == 0
                doSave = false;
            end

            selectedPosition = MBeautifier.DesktopAdapter.getSelection(currentEditorPage);
            configuration = MBeautifier.ConfigurationResolver.resolveForEditorDocument(currentEditorPage);
            MBeautifier.DesktopAdapter.setText(currentEditorPage, ...
                MBeautifier.FormattingPipeline.formatText(MBeautifier.DesktopAdapter.getText(currentEditorPage), configuration));
            MBeautifier.EditorApp.indentPage(currentEditorPage, configuration);

            if ~isempty(selectedPosition)
                MBeautifier.DesktopAdapter.goToPositionInLine(currentEditorPage, selectedPosition(1), selectedPosition(2));
            end

            MBeautifier.DesktopAdapter.activateDocument(currentEditorPage);

            if doSave
                MBeautifier.EditorApp.saveEditorPageIfPossible(currentEditorPage);
            end
        end

        function indentPage(editorPage, configuration)
            neededIndentation = configuration.indentationString();
            makeBlankLinesEmpty = configuration.trimBlankLinesDuringIndentation();
            skipIndentation = strcmp(neededIndentation, '    ');

            if skipIndentation && ~makeBlankLinesEmpty
                return
            end

            textArray = regexp(MBeautifier.DesktopAdapter.getText(editorPage), MBeautifier.Constants.NewLine, 'split');

            for iLine = 1:numel(textArray)
                cText = textArray{iLine};
                if ~skipIndentation
                    cText = MBeautifier.EditorApp.replaceLeadingIndentation(cText, neededIndentation);
                end

                if makeBlankLinesEmpty
                    trimmedLine = strtrim(cText);
                    if isempty(trimmedLine)
                        cText = trimmedLine;
                    end
                end

                textArray{iLine} = cText;
            end

            MBeautifier.DesktopAdapter.setText(editorPage, strjoin(textArray, '\n'));
        end

        function currentEditorPage = requireActiveEditorPage()
            currentEditorPage = MBeautifier.DesktopAdapter.getActiveDocument();
            if isempty(currentEditorPage)
                error('MBeautifier:NoActiveEditorPage', ...
                    ['No active MATLAB Editor page is available. ', ...
                    'Open a file in the MATLAB Editor and try again.']);
            end
        end
    end

    methods (Static, Access = private)
        function saveEditorPageIfPossible(editorPage)
            fileName = MBeautifier.DesktopAdapter.getFilename(editorPage);
            if exist(fileName, 'file') && ~isempty(fileparts(fileName))
                fileattrib(fileName, '+w');
                MBeautifier.DesktopAdapter.saveDocumentAs(editorPage, fileName);
            end
        end

        function cText = replaceLeadingIndentation(cText, neededIndentation)
            [~, ~, whiteSpaceCount] = regexp(cText, '^( )+', 'match');
            if isempty(whiteSpaceCount)
                whiteSpaceCount = 0;
            end

            amountOfReplace = floor(whiteSpaceCount / 4);
            if amountOfReplace == 0
                return;
            end

            searchString = repmat('    ', 1, amountOfReplace);
            replaceString = repmat(neededIndentation, 1, amountOfReplace);
            cText = regexprep(cText, ['^', searchString], replaceString);
        end

        function closeDocumentIfPossible(document)
            if ~isempty(document) && isvalid(document)
                MBeautifier.DesktopAdapter.closeDocument(document);
            end
        end

        function deleteDirectoryIfPossible(path)
            if exist(path, 'dir') == 7
                rmdir(path, 's');
            end
        end
    end
end
