classdef MIndenter < handle
    % Performs code indenting. Should not be used directly but only by
    % MBeautify.
    
    properties (Constant)
        Delimiters = {' ', '\f', '\n', '\r', '\t', '\v', ...
            ','};
        KeywordsIncrease = {'function', 'classdef', 'properties', ...
            'methods', 'if', 'for', 'parfor', 'switch', 'try', 'while', ...
            'arguments', 'enumeration'};
        KeywordsSandwich = {'else', 'elseif', 'case', 'otherwise', ...
            'catch'};
        KeywordsDecrease = {'end', 'end;'};
    end
    
    properties (Access = private)
        Configuration;
    end
    
    methods
        function obj = MIndenter(configuration)
            % Creates a new formatter using the passed configuration.
            obj.Configuration = configuration;
        end
        
        function indentedSource = performIndenting(obj, source)
            % indentation strategy:
            % allfunctions (default) = AllFunctionIndent
            % nestedfunctions = MixedFunctionIndent (MATLAB default)
            % noindent = ClassicFunctionIndent
            strategy = obj.Configuration.specialRule('Indentation_Strategy').Value;
            indent = obj.getIndentationString();
            makeBlankLinesEmpty = obj.Configuration.specialRule('Indentation_TrimBlankLines').ValueAsDouble;

            continuationMode = 0;
            layerNext = 0;
            stack = {};

            lines = regexp(source, MBeautifier.Constants.NewLine, 'split');
            for linect = 1:numel(lines)
                layer = layerNext;

                [lines{linect}, line, words, isOldStyleFunctionCall] = obj.analyzeLine(lines{linect});
                if obj.shouldProcessLine(line, isOldStyleFunctionCall)
                    [layer, layerNext, stack] = obj.processKeywords(words, layer, layerNext, stack, strategy);
                    [continuationMode, layerNext] = obj.updateContinuationMode(words, continuationMode, layerNext);
                end

                lines{linect} = obj.applyIndentation(lines{linect}, layer, indent, makeBlankLinesEmpty);
            end

            indentedSource = strjoin(lines, MBeautifier.Constants.NewLine);
        end
    end
    
    methods (Access = private)
        function indent = getIndentationString(obj)
            indentationCharacter = obj.Configuration.specialRule('IndentationCharacter').Value;
            indentationCount = obj.Configuration.specialRule('IndentationCount').ValueAsDouble;
            indent = MBeautifier.IndentationConfiguration.indentationString( ...
                indentationCharacter, indentationCount);
        end

        function [trimmedLine, line, words, isOldStyleFunctionCall] = analyzeLine(obj, rawLine)
            trimmedLine = strtrim(rawLine);
            line = regexprep(trimmedLine, '(".*")|(''.*'')|(%.*)', '');

            pattern = ['[', strjoin(obj.Delimiters, '|'), ']'];
            words = regexp(line, pattern, 'split');
            isOldStyleFunctionCall = obj.isOldStyleFunctionCall(line);
        end

        function tf = isOldStyleFunctionCall(~, line)
            tf = false;
            if isempty(regexp(line, '^[a-zA-Z0-9_]+\s+[^(=]', 'once'))
                return;
            end

            splitLine = regexp(strtrim(line), ' ', 'split');
            if ~isempty(splitLine) && ~any(strcmp(splitLine{1}, iskeyword())) && exist(splitLine{1}) %#ok<EXIST>
                tf = true;
            end
        end

        function tf = shouldProcessLine(~, line, isOldStyleFunctionCall)
            tf = ~isempty(line) && line(1) ~= '%' && ~isOldStyleFunctionCall;
        end

        function [layer, layerNext, stack] = processKeywords(obj, words, layer, layerNext, stack, strategy)
            for wordct = 1:numel(words)
                currentWord = words{wordct};
                if strcmp(currentWord, '%')
                    break;
                end

                if any(strcmp(currentWord, obj.KeywordsIncrease))
                    [layer, layerNext, stack] = obj.handleIncreaseKeyword(currentWord, layer, layerNext, stack, strategy);
                end

                if any(strcmp(currentWord, obj.KeywordsSandwich)) && wordct == 1
                    layer = layer - 1;
                end

                if any(strcmp(currentWord, obj.KeywordsDecrease))
                    [layer, layerNext, stack] = obj.handleDecreaseKeyword(wordct, layer, layerNext, stack, strategy);
                end
            end
        end

        function [layer, layerNext, stack] = handleIncreaseKeyword(~, currentWord, layer, layerNext, stack, strategy)
            layerNext = layerNext + 1;
            stack{end+1} = currentWord;

            if strcmp(stack{end}, 'function')
                switch lower(strategy)
                    case 'nestedfunctions'
                        if isscalar(stack)
                            layerNext = layerNext - 1;
                        elseif strcmp(stack{end-1}, 'function')
                            layer = layer + 1;
                            layerNext = layerNext + 1;
                        end
                    case 'noindent'
                        layerNext = layerNext - 1;
                end
            end

            if strcmp(stack{end}, 'switch')
                layerNext = layerNext + 1;
            end
        end

        function [layer, layerNext, stack] = handleDecreaseKeyword(~, wordct, layer, layerNext, stack, strategy)
            if wordct == 1
                layer = layer - 1;
            end
            layerNext = layerNext - 1;

            if isempty(stack)
                return;
            end

            if strcmp(stack{end}, 'function')
                switch lower(strategy)
                    case 'nestedfunctions'
                        if isscalar(stack)
                            layerNext = layerNext + 1;
                        elseif strcmp(stack{end-1}, 'function')
                            layer = layer - 1;
                        end
                    case 'noindent'
                        if wordct == 1
                            layer = layer + 1;
                        end
                        layerNext = layerNext + 1;
                end
            end

            if strcmp(stack{end}, 'switch')
                if wordct == 1
                    layer = layer - 1;
                end
                layerNext = layerNext - 1;
            end

            stack(end) = [];
        end

        function [continuationMode, layerNext] = updateContinuationMode(~, words, continuationMode, layerNext)
            if strcmp(words{end}, '...')
                if ~continuationMode
                    continuationMode = 1;
                    layerNext = layerNext + 1;
                end
            elseif continuationMode
                continuationMode = 0;
                layerNext = layerNext - 1;
            end
        end

        function indentedLine = applyIndentation(~, line, layer, indent, makeBlankLinesEmpty)
            indentedLine = line;
            if ~makeBlankLinesEmpty || ~isempty(indentedLine)
                indentedLine = [repmat(indent, 1, layer), indentedLine];
            end
        end
    end
end
