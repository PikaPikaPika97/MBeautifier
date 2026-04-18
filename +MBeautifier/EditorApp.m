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

            if isempty(MBeautifier.DesktopAdapter.getSelectedText(currentEditorPage))
                error('MBeautifier:NoSelectedEditorText', ...
                    ['The active MATLAB Editor page does not contain a selection. ', ...
                    'Select the code you want to format and try again.']);
            end

            if nargin == 0
                doSave = false;
            end

            expandedSelection = [currentSelection(1), 1, currentSelection(3), Inf];

            MBeautifier.DesktopAdapter.setSelection(currentEditorPage, [currentSelection(1), 1, currentSelection(1), Inf]);
            if isempty(strtrim(MBeautifier.DesktopAdapter.getSelectedText(currentEditorPage)))
                lineBeforePosition = currentSelection(1);
            else
                if currentSelection(1) > 1
                    lineBeforePosition = [currentSelection(1) - 1, 1, currentSelection(1) - 1, Inf];
                    MBeautifier.DesktopAdapter.setSelection(currentEditorPage, lineBeforePosition);
                    lineBeforeText = MBeautifier.DesktopAdapter.getSelectedText(currentEditorPage);

                    while lineBeforePosition(1) > 1 && ~isempty(strtrim(lineBeforeText))
                        lineBeforePosition = [lineBeforePosition(1) - 1, 1, lineBeforePosition(1) - 1, Inf];
                        MBeautifier.DesktopAdapter.setSelection(currentEditorPage, lineBeforePosition);
                        lineBeforeText = MBeautifier.DesktopAdapter.getSelectedText(currentEditorPage);
                    end
                else
                    lineBeforePosition = 1;
                end
            end

            expandedSelection = [lineBeforePosition(1), 1, expandedSelection(3), Inf];

            MBeautifier.DesktopAdapter.setSelection(currentEditorPage, [currentSelection(3), 1, currentSelection(3), Inf]);
            if isempty(strtrim(MBeautifier.DesktopAdapter.getSelectedText(currentEditorPage)))
                lineAfterSelection = [currentSelection(3), 1, currentSelection(3), Inf];
            else
                lineAfterSelection = [currentSelection(3) + 1, 1, currentSelection(3) + 1, Inf];
                MBeautifier.DesktopAdapter.setSelection(currentEditorPage, lineAfterSelection);
                lineAfterText = MBeautifier.DesktopAdapter.getSelectedText(currentEditorPage);
                previousSelectionLine = currentSelection(1);

                while ~isequal(lineAfterSelection(1), previousSelectionLine) && ~isempty(strtrim(lineAfterText))
                    previousSelectionLine = lineAfterSelection(1);
                    lineAfterSelection = [lineAfterSelection(1) + 1, 1, lineAfterSelection(1) + 1, Inf];
                    MBeautifier.DesktopAdapter.setSelection(currentEditorPage, lineAfterSelection);
                    lineAfterText = MBeautifier.DesktopAdapter.getSelectedText(currentEditorPage);
                end
            end

            endReached = isequal(lineAfterSelection(1), currentSelection(1));
            expandedSelection = [expandedSelection(1), 1, lineAfterSelection(3), Inf];

            if isequal(expandedSelection(1), 1)
                codeBefore = '';
            else
                codeBeforeSelection = [1, 1, expandedSelection(1), Inf];
                MBeautifier.DesktopAdapter.setSelection(currentEditorPage, codeBeforeSelection);
                codeBefore = [MBeautifier.DesktopAdapter.getSelectedText(currentEditorPage), MBeautifier.Constants.NewLine];
            end

            if endReached
                codeAfter = '';
            else
                codeAfterSelection = [expandedSelection(3), 1, Inf, Inf];
                MBeautifier.DesktopAdapter.setSelection(currentEditorPage, codeAfterSelection);
                codeAfter = MBeautifier.DesktopAdapter.getSelectedText(currentEditorPage);
            end

            MBeautifier.DesktopAdapter.setSelection(currentEditorPage, expandedSelection);
            codeToFormat = MBeautifier.DesktopAdapter.getSelectedText(currentEditorPage);
            selectedPosition = MBeautifier.DesktopAdapter.getSelection(currentEditorPage);
            configuration = MBeautifier.ConfigurationResolver.resolveForEditorDocument(currentEditorPage);
            formattedSource = MBeautifier.FormattingPipeline.formatText(codeToFormat, configuration);

            MBeautifier.DesktopAdapter.setText(currentEditorPage, [codeBefore, formattedSource, codeAfter]);
            MBeautifier.EditorApp.indentPage(currentEditorPage, configuration);
            if ~isempty(selectedPosition)
                MBeautifier.DesktopAdapter.goToPositionInLine(currentEditorPage, selectedPosition(1), selectedPosition(2));
            end
            MBeautifier.DesktopAdapter.setSelection(currentEditorPage, expandedSelection);
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
            MBeautifier.EditorApp.runWithTemporaryEditorIndentPreference(configuration, ...
                @() MBeautifier.DesktopAdapter.smartIndentContents(editorPage));

            indentationCharacter = configuration.specialRule('IndentationCharacter').Value;
            indentationCount = configuration.specialRule('IndentationCount').ValueAsDouble;
            makeBlankLinesEmpty = configuration.specialRule('Indentation_TrimBlankLines').ValueAsDouble;

            if strcmpi(indentationCharacter, 'white-space') && indentationCount == 4 && ~makeBlankLinesEmpty
                return
            end

            neededIndentation = MBeautifier.EditorApp.buildIndentationString(indentationCharacter, indentationCount);
            if isempty(neededIndentation)
                warning('MBeautifier:IllegalSetting:IndentationCharacter', ...
                    ['MBeautifier: The indentation character must be set to "white-space" or "tab". ', ...
                    'MBeautifier using MATLAB defaults.']);
                neededIndentation = '    ';
                indentationCharacter = 'white-space';
            end

            textArray = regexp(MBeautifier.DesktopAdapter.getText(editorPage), MBeautifier.Constants.NewLine, 'split');
            skipIndentation = strcmpi(indentationCharacter, 'white-space') && indentationCount == 4;

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

        function runWithTemporaryEditorIndentPreference(configuration, callback)
            originalPreference = MBeautifier.EditorApp.getEditorIndentPreference();
            restorePreference = onCleanup(@() MBeautifier.EditorApp.restoreEditorIndentPreference(originalPreference));

            MBeautifier.EditorApp.applyEditorIndentPreference(configuration);
            callback();
        end

        function currentEditorPage = requireActiveEditorPage()
            currentEditorPage = MBeautifier.DesktopAdapter.getActiveDocument();
            if isempty(currentEditorPage)
                error('MBeautifier:NoActiveEditorPage', ...
                    ['No active MATLAB Editor page is available. ', ...
                    'Open a file in the MATLAB Editor and try again.']);
            end
        end

        function applyEditorIndentPreference(configuration)
            indentationStrategy = configuration.specialRule('Indentation_Strategy').Value;

            switch lower(indentationStrategy)
                case 'allfunctions'
                    targetPreference = 'AllFunctionIndent';
                case 'nestedfunctions'
                    targetPreference = 'MixedFunctionIndent';
                case 'noindent'
                    targetPreference = 'ClassicFunctionIndent';
                otherwise
                    targetPreference = MBeautifier.EditorApp.getEditorIndentPreference();
            end

            MBeautifier.EditorApp.setEditorIndentPreference(targetPreference);
        end

        function preference = getEditorIndentPreference()
            preference = MBeautifier.EditorPreferenceAdapter.getIndentPreference();
        end

        function restoreEditorIndentPreference(preference)
            MBeautifier.EditorPreferenceAdapter.restoreIndentPreference(preference);
        end

        function setEditorIndentPreference(preference)
            MBeautifier.EditorPreferenceAdapter.setIndentPreference(preference);
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

        function indent = buildIndentationString(indentationCharacter, indentationCount)
            indent = '';
            if strcmpi(indentationCharacter, 'white-space')
                indent = repmat(' ', 1, indentationCount);
            elseif strcmpi(indentationCharacter, 'tab')
                indent = '\t';
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
