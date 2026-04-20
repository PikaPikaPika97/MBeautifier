classdef BlockIndentationEngine < handle
    %BLOCKINDENTATIONENGINE Apply block and continuation indentation.

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
        function obj = BlockIndentationEngine(configuration)
            obj.Configuration = configuration;
        end

        function indentedSource = performIndenting(obj, source)
            strategy = obj.Configuration.specialRule('Indentation_Strategy').Value;
            indent = obj.getIndentationString();
            makeBlankLinesEmpty = obj.Configuration.specialRule('Indentation_TrimBlankLines').ValueAsDouble;

            containerDepth = 0;
            continuationLayerNext = 0;
            layerNext = 0;
            stack = {};
            functionModes = {};
            hasTopLevelScriptCode = false;

            lines = regexp(source, MBeautifier.Constants.NewLine, 'split');
            for linect = 1:numel(lines)
                layer = layerNext;

                [lines{linect}, line, words, isOldStyleFunctionCall] = obj.analyzeLine(lines{linect});
                continuationLayer = obj.continuationLayerForLine(lines{linect}, continuationLayerNext);

                if obj.shouldProcessLine(line, isOldStyleFunctionCall)
                    isScriptLocalFunction = obj.isScriptLocalFunctionStart(words, stack, hasTopLevelScriptCode);
                    if obj.isTopLevelScriptCode(words, stack)
                        hasTopLevelScriptCode = true;
                    end

                    [layer, layerNext, stack, functionModes] = obj.processKeywords( ...
                        words, layer, layerNext, stack, functionModes, strategy, isScriptLocalFunction);
                    [continuationLayerNext, containerDepth] = obj.updateContinuationState( ...
                        line, words, continuationLayer, continuationLayerNext, containerDepth);
                elseif continuationLayerNext && obj.shouldEndContinuationAfterSkippedLine(lines{linect})
                    continuationLayerNext = 0;
                    containerDepth = 0;
                end

                layer = layer + continuationLayer;
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
            line = obj.removeStringsAndComments(trimmedLine);

            pattern = ['[', strjoin(obj.Delimiters, '|'), ']'];
            words = regexp(line, pattern, 'split');
            isOldStyleFunctionCall = obj.isOldStyleFunctionCall(line);
        end

        function line = removeStringsAndComments(~, rawLine)
            output = blanks(numel(rawLine));
            outputIndex = 0;
            stringDelimiter = '';
            previousNonspace = '';
            index = 1;

            while index <= numel(rawLine)
                currentCharacter = rawLine(index);

                if isempty(stringDelimiter)
                    if currentCharacter == '%'
                        break;
                    end

                    if currentCharacter == ''''
                        if MBeautifier.LexicalRules.isTransposeQuote(previousNonspace)
                            outputIndex = outputIndex + 1;
                            output(outputIndex) = currentCharacter;
                        else
                            stringDelimiter = currentCharacter;
                        end
                    elseif currentCharacter == '"'
                        stringDelimiter = currentCharacter;
                    else
                        outputIndex = outputIndex + 1;
                        output(outputIndex) = currentCharacter;
                    end
                elseif currentCharacter == stringDelimiter
                    if index < numel(rawLine) && rawLine(index + 1) == stringDelimiter
                        index = index + 1;
                    else
                        stringDelimiter = '';
                    end
                end

                if isempty(stringDelimiter) && ~isspace(currentCharacter)
                    previousNonspace = currentCharacter;
                end
                index = index + 1;
            end

            line = output(1:outputIndex);
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

        function [layer, layerNext, stack, functionModes] = processKeywords( ...
                obj, words, layer, layerNext, stack, functionModes, strategy, isScriptLocalFunction)
            for wordct = 1:numel(words)
                currentWord = words{wordct};
                if strcmp(currentWord, '%')
                    break;
                end

                if any(strcmp(currentWord, obj.KeywordsIncrease))
                    [layer, layerNext, stack, functionModes] = obj.handleIncreaseKeyword( ...
                        currentWord, layer, layerNext, stack, functionModes, strategy, isScriptLocalFunction);
                end

                if any(strcmp(currentWord, obj.KeywordsSandwich)) && wordct == 1
                    layer = layer - 1;
                end

                if any(strcmp(currentWord, obj.KeywordsDecrease))
                    [layer, layerNext, stack, functionModes] = obj.handleDecreaseKeyword( ...
                        wordct, layer, layerNext, stack, functionModes);
                end
            end
        end

        function [layer, layerNext, stack, functionModes] = handleIncreaseKeyword( ...
                ~, currentWord, layer, layerNext, stack, functionModes, strategy, isScriptLocalFunction)
            layerNext = layerNext + 1;
            stack{end+1} = currentWord;
            functionModes{end+1} = '';

            if strcmp(stack{end}, 'function')
                switch lower(strategy)
                    case 'nestedfunctions'
                        if isscalar(stack)
                            if ~isScriptLocalFunction
                                layerNext = layerNext - 1;
                                functionModes{end} = 'nestedTopNoIndent';
                            end
                        elseif strcmp(stack{end-1}, 'function')
                            layer = layer + 1;
                            layerNext = layerNext + 1;
                            functionModes{end} = 'nestedFunction';
                        end
                    case 'noindent'
                        layerNext = layerNext - 1;
                        functionModes{end} = 'noIndent';
                end
            end

            if strcmp(stack{end}, 'switch')
                layerNext = layerNext + 1;
            end
        end

        function [layer, layerNext, stack, functionModes] = handleDecreaseKeyword( ...
                ~, wordct, layer, layerNext, stack, functionModes)
            if wordct == 1
                layer = layer - 1;
            end
            layerNext = layerNext - 1;

            if isempty(stack)
                return;
            end

            if strcmp(stack{end}, 'function')
                switch functionModes{end}
                    case 'nestedTopNoIndent'
                        layerNext = layerNext + 1;
                    case 'nestedFunction'
                        layer = layer - 1;
                    case 'noIndent'
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
            functionModes(end) = [];
        end

        function layer = continuationLayerForLine(obj, rawLine, continuationLayerNext)
            leadingClosingDepth = min(continuationLayerNext, obj.leadingClosingContainerCount(rawLine));
            layer = continuationLayerNext - leadingClosingDepth;
        end

        function [continuationLayerNext, containerDepth] = updateContinuationState( ...
                obj, line, words, continuationLayer, continuationLayerNext, containerDepth)
            previousContainerDepth = containerDepth;
            depthDelta = obj.containerDepthDelta(line);
            containerDepth = max(0, containerDepth + depthDelta);

            if containerDepth == 0
                if obj.endsWithContinuationToken(line) && ~obj.startsWithBlockOpeningKeyword(words)
                    continuationLayerNext = continuationLayer + 1;
                else
                    continuationLayerNext = 0;
                end
            elseif depthDelta > 0 || previousContainerDepth == 0
                continuationLayerNext = continuationLayer + 1;
            elseif depthDelta < 0
                continuationLayerNext = continuationLayer;
            end
        end

        function tf = shouldEndContinuationAfterSkippedLine(~, line)
            tf = ~isempty(strtrim(line)) && isempty(regexp(strtrim(line), '^%', 'once'));
        end

        function tf = isTopLevelScriptCode(obj, words, stack)
            firstWord = obj.firstSignificantWord(words);
            tf = isempty(stack) && ~isempty(firstWord) && ...
                ~any(strcmp(firstWord, {'function', 'classdef'}));
        end

        function tf = startsWithBlockOpeningKeyword(obj, words)
            firstWord = obj.firstSignificantWord(words);
            tf = any(strcmp(firstWord, obj.KeywordsIncrease));
        end

        function tf = isScriptLocalFunctionStart(obj, words, stack, hasTopLevelScriptCode)
            firstWord = obj.firstSignificantWord(words);
            tf = hasTopLevelScriptCode && isempty(stack) && strcmp(firstWord, 'function') && ...
                obj.Configuration.indentScriptLocalFunctionBodies();
        end

        function word = firstSignificantWord(~, words)
            word = '';
            for idx = 1:numel(words)
                if ~isempty(words{idx})
                    word = words{idx};
                    return;
                end
            end
        end

        function count = leadingClosingContainerCount(~, line)
            trimmedLine = strtrim(line);
            count = 0;
            while count < numel(trimmedLine) && any(trimmedLine(count + 1) == ')]}')
                count = count + 1;
            end
        end

        function delta = containerDepthDelta(~, line)
            openingCount = sum(line == '(' | line == '[' | line == '{');
            closingCount = sum(line == ')' | line == ']' | line == '}');
            delta = openingCount - closingCount;
        end

        function tf = endsWithContinuationToken(~, line)
            tf = ~isempty(regexp(strtrim(line), '\.\.\.$', 'once'));
        end

        function indentedLine = applyIndentation(~, line, layer, indent, makeBlankLinesEmpty)
            indentedLine = line;
            if ~makeBlankLinesEmpty || ~isempty(indentedLine)
                indentedLine = [repmat(indent, 1, layer), indentedLine];
            end
        end
    end
end
