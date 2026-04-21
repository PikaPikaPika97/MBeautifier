classdef EditorSelectionFormatting
    %EDITORSELECTIONFORMATTING Pure selection expansion for Editor formatting.

    methods (Static)
        function request = plan(documentText, currentSelection, selectedText)
            if isempty(selectedText)
                error('MBeautifier:NoSelectedEditorText', ...
                    ['The active MATLAB Editor page does not contain a selection. ', ...
                    'Select the code you want to format and try again.']);
            end

            documentText = char(documentText);
            lineModel = MBeautifier.EditorSelectionFormatting.lineModel(documentText);
            selectionStartLine = MBeautifier.EditorSelectionFormatting.clampLine( ...
                currentSelection(1), lineModel.ContentLineCount);
            selectionEndLine = MBeautifier.EditorSelectionFormatting.clampLine( ...
                currentSelection(3), lineModel.ContentLineCount);

            formatStartLine = MBeautifier.EditorSelectionFormatting.findFormatStartLine( ...
                lineModel.Lines, selectionStartLine);
            formatEndLine = MBeautifier.EditorSelectionFormatting.findFormatEndLine( ...
                lineModel.Lines, selectionEndLine, lineModel.ContentLineCount);
            expandedSelection = MBeautifier.EditorSelectionFormatting.expandedSelection( ...
                lineModel.Lines, formatStartLine, formatEndLine, lineModel.ContentLineCount);

            codeStart = lineModel.LineStarts(formatStartLine);
            codeEnd = lineModel.LineEndsWithNewline(formatEndLine);

            request = struct( ...
                'CodeBefore', MBeautifier.EditorSelectionFormatting.sliceText(documentText, 1, codeStart - 1), ...
                'CodeToFormat', MBeautifier.EditorSelectionFormatting.sliceText(documentText, codeStart, codeEnd), ...
                'CodeAfter', MBeautifier.EditorSelectionFormatting.sliceText(documentText, codeEnd + 1, numel(documentText)), ...
                'ExpandedSelection', expandedSelection, ...
                'RestorePosition', [expandedSelection(1), expandedSelection(2)], ...
                'FormatStartLine', formatStartLine, ...
                'FormatEndLine', formatEndLine);
        end

        function text = rebuild(request, formattedSource)
            text = [request.CodeBefore, formattedSource, request.CodeAfter];
        end
    end

    methods (Static, Access = private)
        function lineModel = lineModel(documentText)
            newlineCharacter = newline;
            newlinePositions = strfind(documentText, newlineCharacter);
            lines = regexp(documentText, newlineCharacter, 'split');

            if isempty(documentText)
                contentLineCount = 1;
            elseif documentText(end) == newlineCharacter
                contentLineCount = max(1, numel(newlinePositions));
            else
                contentLineCount = numel(newlinePositions) + 1;
            end

            lineStarts = zeros(1, contentLineCount);
            lineEndsWithNewline = zeros(1, contentLineCount);
            for iLine = 1:contentLineCount
                if iLine == 1
                    lineStarts(iLine) = 1;
                else
                    lineStarts(iLine) = newlinePositions(iLine - 1) + 1;
                end

                if iLine <= numel(newlinePositions)
                    lineEndsWithNewline(iLine) = newlinePositions(iLine);
                else
                    lineEndsWithNewline(iLine) = numel(documentText);
                end
            end

            lineModel = struct( ...
                'Lines', {lines}, ...
                'ContentLineCount', contentLineCount, ...
                'LineStarts', lineStarts, ...
                'LineEndsWithNewline', lineEndsWithNewline);
        end

        function line = clampLine(line, contentLineCount)
            line = min(max(1, line), contentLineCount);
        end

        function startLine = findFormatStartLine(lines, selectedLine)
            startLine = selectedLine;
            if MBeautifier.EditorSelectionFormatting.isBlankLine(lines, selectedLine)
                return;
            end

            while startLine > 1 && ~MBeautifier.EditorSelectionFormatting.isBlankLine(lines, startLine - 1)
                startLine = startLine - 1;
            end
        end

        function endLine = findFormatEndLine(lines, selectedLine, contentLineCount)
            endLine = selectedLine;
            if MBeautifier.EditorSelectionFormatting.isBlankLine(lines, selectedLine)
                return;
            end

            while endLine < contentLineCount && ~MBeautifier.EditorSelectionFormatting.isBlankLine(lines, endLine + 1)
                endLine = endLine + 1;
            end
        end

        function selection = expandedSelection(lines, formatStartLine, formatEndLine, contentLineCount)
            selectionStartLine = formatStartLine;
            if formatStartLine > 1 && MBeautifier.EditorSelectionFormatting.isBlankLine(lines, formatStartLine - 1)
                selectionStartLine = formatStartLine - 1;
            end

            selectionEndLine = formatEndLine;
            if formatEndLine < contentLineCount && MBeautifier.EditorSelectionFormatting.isBlankLine(lines, formatEndLine + 1)
                selectionEndLine = formatEndLine + 1;
            end

            selection = [selectionStartLine, 1, selectionEndLine, Inf];
        end

        function tf = isBlankLine(lines, lineNumber)
            if lineNumber > numel(lines)
                tf = true;
                return;
            end

            tf = isempty(strtrim(lines{lineNumber}));
        end

        function text = sliceText(documentText, startIndex, endIndex)
            if isempty(documentText) || startIndex > endIndex
                text = '';
                return;
            end

            text = documentText(startIndex:endIndex);
        end
    end
end
