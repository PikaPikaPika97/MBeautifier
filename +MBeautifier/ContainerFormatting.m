classdef ContainerFormatting
    %CONTAINERFORMATTING Format matrix, cell, indexing, and call containers.

    methods (Static)
        function [data, arrayMap] = replaceContainers( ...
                data, configuration, tokenStruct, preserveIndexExpressionSpacing, formatElement)
            % Replaces containers in a code line with container tokens while storing the original container contents in
            % the second output argument.

            arrayMap = containers.Map();
            if isempty(data)
                return
            end

            context = MBeautifier.ContainerFormatting.createContext( ...
                configuration, tokenStruct, preserveIndexExpressionSpacing, formatElement);
            data = regexprep(data, '\s+;', ';');
            [containerBorderIndexes, maxDepth] = MBeautifier.ContainerScanner.calculateDepths(data);
            id = 0;

            while maxDepth > 0
                if isempty(containerBorderIndexes)
                    break;
                end

                [indexes, maxDepth, foundPair] = ...
                    MBeautifier.ContainerFormatting.selectDeepestContainerPair(containerBorderIndexes, maxDepth);
                if ~foundPair
                    continue;
                end

                container = MBeautifier.ContainerFormatting.classifyContainer( ...
                    data, containerBorderIndexes, indexes);
                formattedContainer = MBeautifier.ContainerFormatting.formatContainer(data, container, context);
                [data, arrayMap, id] = MBeautifier.ContainerFormatting.replaceContainerText( ...
                    data, arrayMap, id, container, formattedContainer);
                [containerBorderIndexes, maxDepth] = MBeautifier.ContainerScanner.calculateDepths(data);
            end
        end

        function data = restoreContainers(data, map, configuration)
            % Replaces container tokens with the original container contents.

            arrayTokenList = map.keys();
            if isempty(arrayTokenList)
                return;
            end

            for iKey = numel(arrayTokenList):-1:1
                data = regexprep(data, arrayTokenList{iKey}, regexptranslate('escape', map(arrayTokenList{iKey})));
            end
            data = regexprep(data, configuration.operatorPaddingRule('Comma').Token, configuration.operatorPaddingRule('Comma').ValueTo);
        end
    end

    methods (Static, Access = private)
        function context = createContext(configuration, tokenStruct, preserveIndexExpressionSpacing, formatElement)
            context = struct( ...
                'configuration', configuration, ...
                'tokenStruct', tokenStruct, ...
                'preserveIndexExpressionSpacing', preserveIndexExpressionSpacing, ...
                'formatElement', formatElement, ...
                'commaToken', configuration.operatorPaddingRule('Comma').Token);

            % TODO: Bind obj.AllOperators in a filtered manner
            nonUnaryOperators = {'&', '&&', '|', '||', '/', './', '\', '.\', '*', '.*', ':', '^', '.^', '<', '>', '==', '>=', '<=', '~='};
            context.nonUnaryOperators = nonUnaryOperators;
            context.singleCharacterNonUnaryOperators = nonUnaryOperators(cellfun(@numel, nonUnaryOperators) == 1);
            context.twoCharacterNonUnaryOperators = nonUnaryOperators(cellfun(@numel, nonUnaryOperators) == 2);
            context.operators = [nonUnaryOperators(:)', {'+'}, {'-'}, {'~'}];
        end

        function [indexes, maxDepth, foundPair] = selectDeepestContainerPair(containerBorderIndexes, maxDepth)
            indexes = find([containerBorderIndexes{:, 2}] == maxDepth, 2);
            foundPair = true;

            if ~numel(indexes) || mod(numel(indexes), 2) ~= 0
                maxDepth = maxDepth - 1;
                foundPair = false;
            end
        end

        function container = classifyContainer(data, containerBorderIndexes, indexes)
            container = struct();
            container.indexes = indexes;
            container.openIndex = containerBorderIndexes{indexes(1), 1};
            container.closeIndex = containerBorderIndexes{indexes(2), 1};
            container.openingBracket = data(container.openIndex);
            container.closingBracket = data(container.closeIndex);

            [container.isWhitespaceDelimiter, container.contRegex] = ...
                MBeautifier.ContainerFormatting.containerIndexingPattern(data, containerBorderIndexes, indexes);
            [container.isIndexing, container.precedingKeyword] = ...
                MBeautifier.ContainerFormatting.classifyIndexing(data, container);
            [container.doIndexing, container.contType] = ...
                MBeautifier.ContainerFormatting.indexingFormattingMode(container);
        end

        function [isWhitespaceDelimiter, contRegex] = containerIndexingPattern(data, containerBorderIndexes, indexes)
            openingBracket = data(containerBorderIndexes{indexes(1), 1});
            isEmbeddedContainer = indexes(1) > 1;

            if isEmbeddedContainer && ...
                    (data(containerBorderIndexes{indexes(1)-1, 1}) == '[' ...
                    || data(containerBorderIndexes{indexes(1)-1, 1}) == '{')
                isWhitespaceDelimiter = true;
                contRegex = ['[a-zA-Z0-9_][', openingBracket, ']$'];
            else
                isWhitespaceDelimiter = false;
                contRegex = ['[a-zA-Z0-9_]\s*[', openingBracket, ']$'];
            end
        end

        function [isContainerIndexing, precedingKeyword] = classifyIndexing(data, container)
            isContainerIndexing = numel(regexp(data(1:container.openIndex), container.contRegex));
            precedingKeyword = false;

            if isContainerIndexing
                [isContainerIndexing, precedingKeyword] = ...
                    MBeautifier.ContainerFormatting.removeKeywordIndexing(data, container.openIndex);
            end

            if isContainerIndexing && strcmp(container.openingBracket, '(') ...
                    && MBeautifier.ContainerFormatting.isLikelyFunctionCallContainer(data, container.openIndex)
                isContainerIndexing = false;
            end
        end

        function [isContainerIndexing, precedingKeyword] = removeKeywordIndexing(data, openIndex)
            isContainerIndexing = true;
            precedingKeyword = false;
            keywords = iskeyword();
            prevStr = strtrim(data(1:openIndex-1));

            if numel(prevStr) < 2
                return;
            end

            for i = 1:numel(keywords)
                if numel(regexp(prevStr, ['(\s|^)', keywords{i}, '$']))
                    isContainerIndexing = false;
                    precedingKeyword = true;
                    break;
                end
            end
        end

        function [doIndexing, contType] = indexingFormattingMode(container)
            doIndexing = container.isIndexing;
            contType = '';

            if ~doIndexing
                return;
            end

            if strcmp(container.openingBracket, '(')
                contType = 'matrix';
            elseif strcmp(container.openingBracket, '{')
                contType = 'cell';
            else
                doIndexing = false;
            end
        end

        function formattedContainer = formatContainer(data, container, context)
            originalContainer = data(container.openIndex:container.closeIndex);
            normalizedContainer = MBeautifier.ContainerFormatting.normalizeContainerText( ...
                originalContainer, container);

            if container.doIndexing && context.preserveIndexExpressionSpacing
                formattedContainer = strtrim(originalContainer);
            elseif ~strcmp(container.openingBracket, '(')
                formattedContainer = MBeautifier.ContainerFormatting.formatNonParenthesisContainer( ...
                    normalizedContainer, container, context);
            else
                formattedContainer = MBeautifier.ContainerFormatting.formatBracketInterior( ...
                    normalizedContainer, container, context);
            end
        end

        function text = normalizeContainerText(text, container)
            text = regexprep(text, '\s+', ' ');
            text = regexprep(text, [container.openingBracket, '\s+'], container.openingBracket);
            text = regexprep(text, ['\s+', container.closingBracket], container.closingBracket);
        end

        function formattedContainer = formatNonParenthesisContainer(containerText, container, context)
            if container.doIndexing
                formattedContainer = MBeautifier.ContainerFormatting.formatBracketInterior( ...
                    containerText, container, context);
            else
                formattedContainer = MBeautifier.ContainerFormatting.formatDelimitedContainer( ...
                    containerText, container, context);
            end
        end

        function formattedContainer = formatBracketInterior(containerText, container, context)
            formattedContainer = strtrim(containerText);
            formattedContainer = [ ...
                formattedContainer(1), ...
                strtrim(feval(context.formatElement, ...
                formattedContainer(2:end-1), container.doIndexing, container.contType, true)), ...
                formattedContainer(end)];
        end

        function formattedContainer = formatDelimitedContainer(containerText, container, context)
            elementsCell = MBeautifier.ContainerFormatting.splitDelimitedContainerElements( ...
                containerText, container);
            elementsCell = MBeautifier.ContainerFormatting.moveLeadingCommasToPreviousElements(elementsCell);
            elementsCell = MBeautifier.ContainerFormatting.formatDelimitedElements( ...
                elementsCell, container, context);
            elementsCell(cellfun('isempty', elementsCell)) = [];

            if ~isempty(elementsCell)
                elementsCell{end} = strtrim(feval(context.formatElement, ...
                    elementsCell{end}, container.doIndexing, container.contType, true));
            end
            formattedContainer = [container.openingBracket, elementsCell{:}, container.closingBracket];
        end

        function elementsCell = splitDelimitedContainerElements(containerText, ~)
            elementsCell = regexp(containerText, ' ', 'split');
            firstElem = strtrim(elementsCell{1});
            lastElem = strtrim(elementsCell{end});

            if isscalar(elementsCell)
                elementsCell{1} = firstElem(2:end-1);
            else
                elementsCell{1} = firstElem(2:end);
                elementsCell{end} = lastElem(1:end-1);
            end
        end

        function elementsCell = moveLeadingCommasToPreviousElements(elementsCell)
            for iElem = 1:numel(elementsCell)
                elem = strtrim(elementsCell{iElem});
                if numel(elem) && strcmp(elem(1), ',')
                    elem = elem(2:end);
                    if iElem > 1
                        elementsCell{iElem-1} = [elementsCell{iElem-1}, ','];
                    end
                end
                elementsCell{iElem} = elem;
            end
        end

        function elementsCell = formatDelimitedElements(elementsCell, container, context)
            isInNestedContainer = 0;
            inlineMatrix = context.configuration.inlineContinuousLinesInMatrixes();
            inlineCurly = context.configuration.inlineContinuousLinesInCurlyBracket();

            for elemInd = 1:numel(elementsCell) - 1
                currElem = strtrim(elementsCell{elemInd});
                nextElem = strtrim(elementsCell{elemInd+1});

                if ~numel(currElem)
                    continue;
                end

                isInNestedContainer = isInNestedContainer || numel(strfind(currElem, container.openingBracket));
                isInNestedContainer = isInNestedContainer && ~numel(strfind(currElem, container.closingBracket));

                currElemStripped = MBeautifier.ContainerFormatting.stripContainerBrackets(currElem, container);
                nextElemStripped = MBeautifier.ContainerFormatting.stripContainerBrackets(nextElem, container);

                if MBeautifier.ContinuationFormatting.isContinueToken(nextElemStripped, context.tokenStruct) ...
                        && numel(elementsCell) > elemInd + 1
                    nextElem = strtrim(elementsCell{elemInd+2});
                    nextElemStripped = MBeautifier.ContainerFormatting.stripContainerBrackets(nextElem, container);
                end

                [elementsCell, currElem, addCommas, skipElement] = ...
                    MBeautifier.ContainerFormatting.applyContinuationElementRules( ...
                    elementsCell, elemInd, currElem, container, context, inlineMatrix, inlineCurly);
                if skipElement
                    continue;
                end

                [elementsCell, currElem, currElemStripped, nextElemStripped, shouldStop] = ...
                    MBeautifier.ContainerFormatting.mergeUnaryOperatorElement( ...
                    elementsCell, elemInd, currElem, nextElem, currElemStripped, nextElemStripped, container, context);
                if shouldStop
                    break;
                end

                currElem = strtrim(feval(context.formatElement, ...
                    currElem, container.doIndexing, container.contType, true));
                elementsCell{elemInd} = MBeautifier.ContainerFormatting.formatDelimitedElementSeparator( ...
                    currElem, currElemStripped, nextElemStripped, addCommas, isInNestedContainer, context);
            end
        end

        function stripped = stripContainerBrackets(element, container)
            stripped = regexprep(element, ['[', container.openingBracket, container.closingBracket, ']'], '');
        end

        function [elementsCell, currElem, addCommas, skipElement] = applyContinuationElementRules( ...
                elementsCell, elemInd, currElem, container, context, inlineMatrix, inlineCurly)
            skipElement = false;

            if strcmp(container.openingBracket, '[')
                addCommas = context.configuration.addCommasToMatrices();
                if MBeautifier.ContinuationFormatting.isContinueToken(currElem, context.tokenStruct)
                    if inlineMatrix
                        elementsCell{elemInd} = '';
                        skipElement = true;
                    else
                        currElem = context.tokenStruct.ContinueMatrixToken.Token;
                    end
                end
            else
                addCommas = context.configuration.addCommasToCellArrays();
                if MBeautifier.ContinuationFormatting.isContinueToken(currElem, context.tokenStruct)
                    if inlineCurly
                        elementsCell{elemInd} = '';
                        skipElement = true;
                    else
                        currElem = context.tokenStruct.ContinueCurlyToken.Token;
                    end
                end
            end
        end

        function [elementsCell, currElem, currElemStripped, nextElemStripped, shouldStop] = ...
                mergeUnaryOperatorElement(elementsCell, elemInd, currElem, nextElem, ...
                currElemStripped, nextElemStripped, container, context)
            shouldStop = false;
            lastChar = currElem(end);
            if lastChar ~= '-' && lastChar ~= '+' && lastChar ~= '~'
                return;
            end

            prevChar = MBeautifier.ContainerFormatting.previousElementLastCharacter( ...
                elementsCell, elemInd, context.commaToken);
            if isempty(prevChar) || prevChar == ','
                currElem = horzcat(currElem, nextElem);
                currElemStripped = MBeautifier.ContainerFormatting.stripContainerBrackets(currElem, container);
                elementsCell{elemInd+1} = '';
                if numel(elementsCell) > elemInd + 1
                    nextElem = strtrim(elementsCell{elemInd+2});
                    nextElemStripped = MBeautifier.ContainerFormatting.stripContainerBrackets(nextElem, container);
                else
                    elementsCell{elemInd} = currElem;
                    shouldStop = true;
                end
            end
        end

        function prevChar = previousElementLastCharacter(elementsCell, elemInd, commaToken)
            prevChar = [];
            currElem = strtrim(elementsCell{elemInd});
            if numel(currElem) > 1
                prevChar = currElem(end-1);
            elseif elemInd > 1
                prevElems = strtrim(elementsCell(1:elemInd-1));
                prevElems = prevElems(~cellfun(@isempty, prevElems));
                prevElem = prevElems{end};
                if numel(prevElem) >= numel(commaToken) && ...
                        strcmp(prevElem(end-numel(commaToken)+1:end), commaToken)
                    prevChar = ',';
                else
                    prevChar = prevElem(end);
                end
            end
        end

        function element = formatDelimitedElementSeparator( ...
                currElem, currElemStripped, nextElemStripped, addCommas, isInNestedContainer, context)
            numNext = numel(nextElemStripped);

            if ~addCommas || ...
                    isempty(currElem) || ...
                    strcmp(currElem(end), ',') || ...
                    strcmp(currElem(end), ';') || ...
                    isInNestedContainer || ...
                    MBeautifier.ContinuationFormatting.isContinueToken(currElem, context.tokenStruct) || ...
                    any(strcmp(currElemStripped, context.operators)) || ...
                    (~isempty(currElemStripped) && any(strcmp(currElemStripped(end), context.operators))) || ...
                    (numNext >= 1 && any(strcmp(nextElemStripped(1), context.singleCharacterNonUnaryOperators))) || ...
                    (numNext > 1 && any(strcmp(nextElemStripped(1:2), context.twoCharacterNonUnaryOperators))) || ...
                    (numNext == 1 && any(strcmp(nextElemStripped, context.operators))) || ...
                    numel(regexp(currElemStripped, '^@#MBeauty_ArrayToken_\d+#$'))
                element = [currElem, ' '];
            else
                element = [currElem, context.commaToken];
            end
        end

        function [data, arrayMap, id] = replaceContainerText(data, arrayMap, id, container, formattedContainer)
            dataParts = cell(1, 3);
            dataParts{1} = MBeautifier.ContainerFormatting.containerPrefix(data, container);
            dataParts{end} = MBeautifier.ContainerFormatting.containerSuffix(data, container);

            idAsStr = num2str(id);
            idStr = [repmat('0', 1, 5-numel(idAsStr)), idAsStr];
            tokenOfCurElem = ['#MBeauty_ArrayToken_', idStr, '#'];
            arrayMap(tokenOfCurElem) = formattedContainer;
            id = id + 1;
            dataParts{2} = tokenOfCurElem;
            data = horzcat(dataParts{:});
        end

        function prefix = containerPrefix(data, container)
            if container.openIndex == 1
                prefix = '';
                return;
            end

            prefix = data(1:container.openIndex-1);
            if container.isIndexing
                if container.isWhitespaceDelimiter && prefix(end) == ' '
                    prefix = [strtrim(prefix), ' '];
                else
                    prefix = strtrim(prefix);
                end
            elseif container.precedingKeyword
                prefix = strtrim(prefix);
                prefix = [prefix, ' '];
            end
        end

        function suffix = containerSuffix(data, container)
            if container.closeIndex == numel(data)
                suffix = '';
            else
                suffix = data(container.closeIndex+1:end);
            end
        end

        function tf = isLikelyFunctionCallContainer(data, openingIndex)
            % Treat known functions on the MATLAB path as calls, not matrix indexing.
            tf = false;
            if openingIndex <= 1 || data(openingIndex) ~= '('
                return;
            end

            candidate = regexp(data(1:openingIndex-1), '([a-zA-Z][a-zA-Z0-9_]*)\s*$', 'tokens', 'once');
            if isempty(candidate)
                return;
            end

            candidateName = candidate{1};
            if any(strcmp(candidateName, iskeyword()))
                return;
            end

            tf = exist(candidateName) ~= 0; %#ok<EXIST>
        end
    end
end
