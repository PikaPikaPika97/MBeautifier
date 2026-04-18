classdef EditorApp
    %EDITORAPP MATLAB Editor integration helpers for MBeautifier.

    methods (Static)
        function formatFile(file, outFile)
            MBeautifier.FormattingPipeline.requireExistingFile(file);

            isOpen = matlab.desktop.editor.isOpen(file);
            document = matlab.desktop.editor.openDocument(file);
            configuration = MBeautifier.FormattingPipeline.getConfiguration();
            document.Text = MBeautifier.FormattingPipeline.formatText(document.Text, configuration);

            MBeautifier.EditorApp.indentPage(document, configuration);

            if nargin >= 2
                if exist(outFile, 'file')
                    fileattrib(outFile, '+w');
                end

                document.saveAs(outFile);
                if ~isOpen
                    document.close();
                end
            end
        end

        function formatEditorSelection(doSave)
            currentEditorPage = MBeautifier.EditorApp.requireActiveEditorPage();
            currentSelection = currentEditorPage.Selection;

            if isempty(currentEditorPage.SelectedText)
                error('MBeautifier:NoSelectedEditorText', ...
                    ['The active MATLAB Editor page does not contain a selection. ', ...
                    'Select the code you want to format and try again.']);
            end

            if nargin == 0
                doSave = false;
            end

            expandedSelection = [currentSelection(1), 1, currentSelection(3), Inf];

            currentEditorPage.Selection = [currentSelection(1), 1, currentSelection(1), Inf];
            if isempty(strtrim(currentEditorPage.SelectedText))
                lineBeforePosition = currentSelection(1);
            else
                if currentSelection(1) > 1
                    lineBeforePosition = [currentSelection(1) - 1, 1, currentSelection(1) - 1, Inf];
                    currentEditorPage.Selection = lineBeforePosition;
                    lineBeforeText = currentEditorPage.SelectedText;

                    while lineBeforePosition(1) > 1 && ~isempty(strtrim(lineBeforeText))
                        lineBeforePosition = [lineBeforePosition(1) - 1, 1, lineBeforePosition(1) - 1, Inf];
                        currentEditorPage.Selection = lineBeforePosition;
                        lineBeforeText = currentEditorPage.SelectedText;
                    end
                else
                    lineBeforePosition = 1;
                end
            end

            expandedSelection = [lineBeforePosition(1), 1, expandedSelection(3), Inf];

            currentEditorPage.Selection = [currentSelection(3), 1, currentSelection(3), Inf];
            if isempty(strtrim(currentEditorPage.SelectedText))
                lineAfterSelection = [currentSelection(3), 1, currentSelection(3), Inf];
            else
                lineAfterSelection = [currentSelection(3) + 1, 1, currentSelection(3) + 1, Inf];
                currentEditorPage.Selection = lineAfterSelection;
                lineAfterText = currentEditorPage.SelectedText;
                previousSelectionLine = currentSelection(1);

                while ~isequal(lineAfterSelection(1), previousSelectionLine) && ~isempty(strtrim(lineAfterText))
                    previousSelectionLine = lineAfterSelection(1);
                    lineAfterSelection = [lineAfterSelection(1) + 1, 1, lineAfterSelection(1) + 1, Inf];
                    currentEditorPage.Selection = lineAfterSelection;
                    lineAfterText = currentEditorPage.SelectedText;
                end
            end

            endReached = isequal(lineAfterSelection(1), currentSelection(1));
            expandedSelection = [expandedSelection(1), 1, lineAfterSelection(3), Inf];

            if isequal(expandedSelection(1), 1)
                codeBefore = '';
            else
                codeBeforeSelection = [1, 1, expandedSelection(1), Inf];
                currentEditorPage.Selection = codeBeforeSelection;
                codeBefore = [currentEditorPage.SelectedText, MBeautifier.Constants.NewLine];
            end

            if endReached
                codeAfter = '';
            else
                codeAfterSelection = [expandedSelection(3), 1, Inf, Inf];
                currentEditorPage.Selection = codeAfterSelection;
                codeAfter = currentEditorPage.SelectedText;
            end

            currentEditorPage.Selection = expandedSelection;
            codeToFormat = currentEditorPage.SelectedText;
            selectedPosition = currentEditorPage.Selection;
            configuration = MBeautifier.FormattingPipeline.getConfiguration();
            formattedSource = MBeautifier.FormattingPipeline.formatText(codeToFormat, configuration);

            currentEditorPage.Text = [codeBefore, formattedSource, codeAfter];
            MBeautifier.EditorApp.indentPage(currentEditorPage, configuration);
            if ~isempty(selectedPosition)
                currentEditorPage.goToPositionInLine(selectedPosition(1), selectedPosition(2));
            end
            currentEditorPage.Selection = expandedSelection;
            currentEditorPage.makeActive();

            if doSave
                MBeautifier.EditorApp.saveEditorPageIfPossible(currentEditorPage);
            end
        end

        function formatCurrentEditorPage(doSave)
            currentEditorPage = MBeautifier.EditorApp.requireActiveEditorPage();

            if nargin == 0
                doSave = false;
            end

            selectedPosition = currentEditorPage.Selection;
            configuration = MBeautifier.FormattingPipeline.getConfiguration();
            currentEditorPage.Text = MBeautifier.FormattingPipeline.formatText(currentEditorPage.Text, configuration);
            MBeautifier.EditorApp.indentPage(currentEditorPage, configuration);

            if ~isempty(selectedPosition)
                currentEditorPage.goToPositionInLine(selectedPosition(1), selectedPosition(2));
            end

            currentEditorPage.makeActive();

            if doSave
                MBeautifier.EditorApp.saveEditorPageIfPossible(currentEditorPage);
            end
        end

        function indentPage(editorPage, configuration)
            MBeautifier.EditorApp.runWithTemporaryEditorIndentPreference(configuration, ...
                @() editorPage.smartIndentContents());

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

            textArray = regexp(editorPage.Text, MBeautifier.Constants.NewLine, 'split');
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

            editorPage.Text = strjoin(textArray, '\n');
        end

        function runWithTemporaryEditorIndentPreference(configuration, callback)
            originalPreference = MBeautifier.EditorApp.getEditorIndentPreference();
            restorePreference = onCleanup(@() MBeautifier.EditorApp.restoreEditorIndentPreference(originalPreference)); %#ok<NASGU>

            MBeautifier.EditorApp.applyEditorIndentPreference(configuration);
            callback();
        end

        function currentEditorPage = requireActiveEditorPage()
            currentEditorPage = matlab.desktop.editor.getActive();
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
            preference = char(com.mathworks.services.Prefs.getStringPref('EditorMFunctionIndentType'));
        end

        function restoreEditorIndentPreference(preference)
            currentPreference = MBeautifier.EditorApp.getEditorIndentPreference();
            if ~strcmp(currentPreference, preference)
                MBeautifier.EditorApp.setEditorIndentPreference(preference);
            end
        end

        function setEditorIndentPreference(preference)
            com.mathworks.services.Prefs.setStringPref('EditorMFunctionIndentType', preference);
        end
    end

    methods (Static, Access = private)
        function saveEditorPageIfPossible(editorPage)
            fileName = editorPage.Filename;
            if exist(fileName, 'file') && ~isempty(fileparts(fileName))
                fileattrib(fileName, '+w');
                editorPage.saveAs(editorPage.Filename);
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
    end
end
