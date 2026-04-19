classdef SourceLine
    %SOURCELINE Lexical analysis for one MATLAB source line.

    methods (Static)
        function analysis = analyze(line, isInBlockComment, blockCommentDepth)
            arguments
                line char
                isInBlockComment (1,1) logical = false
                blockCommentDepth (1,1) double = 0
            end

            trimmedLine = strtrim(line);
            analysis = struct( ...
                'Code', line, ...
                'Comment', '', ...
                'SplittingPosition', -1, ...
                'IsSectionSeparator', false, ...
                'IsInBlockComment', isInBlockComment, ...
                'BlockCommentDepth', blockCommentDepth, ...
                'Tokens', MBeautifier.SourceLine.emptyTokenArray());

            if isempty(trimmedLine)
                analysis.Code = line;
                return;
            end

            [analysis, handled] = MBeautifier.SourceLine.handleWholeLineContext(analysis, line, trimmedLine);
            if handled
                return;
            end

            [splittingPosition, tokens] = MBeautifier.SourceLine.findFirstCodeBoundary(line);
            analysis.Tokens = tokens;
            analysis.SplittingPosition = splittingPosition;

            if splittingPosition == 1
                analysis.Code = '';
                analysis.Comment = line;
            elseif splittingPosition == -1
                analysis.Code = line;
                analysis.Comment = '';
            else
                analysis.Code = line(1:max(splittingPosition - 1, 1));
                analysis.Comment = strtrim(line(splittingPosition:end));
            end
        end
    end

    methods (Static, Access = private)
        function [analysis, handled] = handleWholeLineContext(analysis, line, trimmedLine)
            handled = true;

            if strcmp(trimmedLine, '%{')
                analysis.BlockCommentDepth = analysis.BlockCommentDepth + 1;
                analysis.IsInBlockComment = true;
                analysis.SplittingPosition = 1;
            elseif strcmp(trimmedLine, '%}') && analysis.IsInBlockComment
                analysis.BlockCommentDepth = analysis.BlockCommentDepth - 1;
                analysis.IsInBlockComment = analysis.BlockCommentDepth > 0;
                analysis.SplittingPosition = 1;
            elseif analysis.IsInBlockComment
                analysis.SplittingPosition = 1;
            elseif startsWith(trimmedLine, '%') || startsWith(trimmedLine, 'import ')
                analysis.SplittingPosition = 1;
            elseif startsWith(trimmedLine, '!')
                analysis.SplittingPosition = 1;
            else
                handled = false;
                return;
            end

            analysis.Code = '';
            analysis.Comment = line;
            if ~analysis.IsInBlockComment && ~isempty(regexp(trimmedLine, '^%%(\s+|$)', 'once'))
                analysis.IsSectionSeparator = true;
            end
        end

        function [splittingPosition, tokens] = findFirstCodeBoundary(line)
            splittingPosition = -1;
            tokens = MBeautifier.SourceLine.emptyTokenArray();
            tokenCount = 0;
            stringDelimiter = '';
            previousNonspace = '';
            index = 1;

            while index <= numel(line)
                currentCharacter = line(index);

                if isempty(stringDelimiter)
                    if currentCharacter == '%' || currentCharacter == '!'
                        [tokens, ~] = MBeautifier.SourceLine.appendToken( ...
                            tokens, tokenCount, 'boundary', index, index);
                        splittingPosition = index;
                        return;
                    end

                    if MBeautifier.SourceLine.startsEllipsis(line, index)
                        [tokens, ~] = MBeautifier.SourceLine.appendToken( ...
                            tokens, tokenCount, 'ellipsis', index, index + 2);
                        splittingPosition = index + 3;
                        return;
                    end

                    if currentCharacter == ''''
                        if MBeautifier.SourceLine.isTransposeQuote(previousNonspace)
                            [tokens, tokenCount] = MBeautifier.SourceLine.appendToken( ...
                                tokens, tokenCount, 'transpose', index, index);
                        else
                            stringDelimiter = currentCharacter;
                            [tokens, tokenCount] = MBeautifier.SourceLine.appendToken( ...
                                tokens, tokenCount, 'stringStart', index, index);
                        end
                    elseif currentCharacter == '"'
                        stringDelimiter = currentCharacter;
                        [tokens, tokenCount] = MBeautifier.SourceLine.appendToken( ...
                            tokens, tokenCount, 'stringStart', index, index);
                    end
                else
                    if currentCharacter == stringDelimiter
                        if index < numel(line) && line(index + 1) == stringDelimiter
                            index = index + 1;
                        else
                            [tokens, tokenCount] = MBeautifier.SourceLine.appendToken( ...
                                tokens, tokenCount, 'stringEnd', index, index);
                            stringDelimiter = '';
                        end
                    end
                end

                if isempty(stringDelimiter) && ~isspace(currentCharacter)
                    previousNonspace = currentCharacter;
                end
                index = index + 1;
            end

            tokens = tokens(1:tokenCount);
        end

        function tf = startsEllipsis(line, index)
            tf = index <= numel(line) - 2 && strcmp(line(index:index + 2), '...');
        end

        function tf = isTransposeQuote(previousNonspace)
            tf = ~isempty(previousNonspace) && ...
                ~isempty(regexp(previousNonspace, '[a-zA-Z0-9_\)\]\}\.''"]', 'once'));
        end

        function tokens = emptyTokenArray()
            tokens = repmat(struct('Type', '', 'Start', 0, 'End', 0), 1, 0);
        end

        function [tokens, tokenCount] = appendToken(tokens, tokenCount, type, startIndex, endIndex)
            tokenCount = tokenCount + 1;
            if tokenCount > numel(tokens)
                tokens = [tokens, repmat(struct('Type', '', 'Start', 0, 'End', 0), 1, max(1, numel(tokens)))];
            end

            tokens(tokenCount) = struct('Type', type, 'Start', startIndex, 'End', endIndex);
        end
    end
end
