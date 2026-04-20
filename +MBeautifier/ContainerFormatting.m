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

            data = regexprep(data, '\s+;', ';');

            % TODO: Bind obj.AllOperators in in a filtered manner
            nonUnaryOperatorArray = {'&', '&&', '|', '||', '/', './', '\', '.\', '*', '.*', ':', '^', '.^', '<', '>', '==', '>=', '<=', '~='};
            nonUnaryOperatorArray1 = nonUnaryOperatorArray(cellfun(@numel, nonUnaryOperatorArray) == 1);
            nonUnaryOperatorArray2 = nonUnaryOperatorArray(cellfun(@numel, nonUnaryOperatorArray) == 2);
            operatorArray = [nonUnaryOperatorArray(:)', {'+'}, {'-'}, {'~'}];
            contTokenStructMatrix = tokenStruct.ContinueMatrixToken;
            contTokenStructCurly = tokenStruct.ContinueCurlyToken;
            commaToken = configuration.operatorPaddingRule('Comma').Token;

            [containerBorderIndexes, maxDepth] = MBeautifier.ContainerScanner.calculateDepths(data);

            id = 0;

            while maxDepth > 0
                if isempty(containerBorderIndexes)
                    break;
                end

                indexes = find([containerBorderIndexes{:, 2}] == maxDepth, 2);

                if ~numel(indexes) || mod(numel(indexes), 2) ~= 0
                    maxDepth = maxDepth - 1;
                    continue;
                end

                openingBracket = data(containerBorderIndexes{indexes(1), 1});
                closingBracket = data(containerBorderIndexes{indexes(2), 1});

                %% Calculate container indexing

                % Container indexing is like:
                %   - "myArray{2}" but NOT "myArray {2}"
                %   - "myMatrix(4)" or "myMatrix (4)"
                %
                % Exceptions:
                %   - NOT after keywords: while(true)
                %   - "myMatrix (4)" is not working inside other containers, like: "[myArray (4)]" must be translated as "[myArray, (4)]"

                % Determine if whitespace can be a delimiter in this context
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

                isContainerIndexing = numel(regexp(data(1:containerBorderIndexes{indexes(1), 1}), contRegex));
                preceedingKeyWord = false;
                if isContainerIndexing
                    keywords = iskeyword();
                    prevStr = strtrim(data(1:containerBorderIndexes{indexes(1), 1}-1));

                    if numel(prevStr) >= 2
                        for i = 1:numel(keywords)
                            if numel(regexp(prevStr, ['(\s|^)', keywords{i}, '$']))
                                isContainerIndexing = false;
                                preceedingKeyWord = true;
                                break;
                            end
                        end
                    end
                end

                if isContainerIndexing && strcmp(openingBracket, '(') ...
                        && MBeautifier.ContainerFormatting.isLikelyFunctionCallContainer( ...
                        data, containerBorderIndexes{indexes(1), 1})
                    isContainerIndexing = false;
                end

                %%

                doIndexing = isContainerIndexing;
                contType = '';
                if doIndexing
                    if strcmp(openingBracket, '(')
                        doIndexing = true;
                        contType = 'matrix';
                    elseif strcmp(openingBracket, '{')
                        doIndexing = true;
                        contType = 'cell';
                    else
                        doIndexing = false;
                    end
                end

                str = data(containerBorderIndexes{indexes(1), 1}:containerBorderIndexes{indexes(2), 1});
                originalStr = str;
                str = regexprep(str, '\s+', ' ');
                str = regexprep(str, [openingBracket, '\s+'], openingBracket);
                str = regexprep(str, ['\s+', closingBracket], closingBracket);

                if doIndexing && preserveIndexExpressionSpacing
                    strNew = strtrim(originalStr);
                elseif ~strcmp(openingBracket, '(')
                    if doIndexing
                        strNew = strtrim(str);
                        strNew = [strNew(1), strtrim(formatElement(strNew(2:end-1), doIndexing, contType, true)), strNew(end)];
                    else
                        elementsCell = regexp(str, ' ', 'split');

                        firstElem = strtrim(elementsCell{1});
                        lastElem = strtrim(elementsCell{end});

                        if isscalar(elementsCell)
                            elementsCell{1} = firstElem(2:end-1);
                        else
                            elementsCell{1} = firstElem(2:end);
                            elementsCell{end} = lastElem(1:end-1);
                        end

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

                        isInCurlyBracket = 0;
                        inlineMatrix = configuration.inlineContinuousLinesInMatrixes();
                        inlineCurly = configuration.inlineContinuousLinesInCurlyBracket();
                        for elemInd = 1:numel(elementsCell) - 1

                            currElem = strtrim(elementsCell{elemInd});
                            nextElem = strtrim(elementsCell{elemInd+1});

                            if ~numel(currElem)
                                continue;
                            end

                            isInCurlyBracket = isInCurlyBracket || numel(strfind(currElem, openingBracket));
                            isInCurlyBracket = isInCurlyBracket && ~numel(strfind(currElem, closingBracket));

                            currElemStripped = regexprep(currElem, ['[', openingBracket, closingBracket, ']'], '');
                            nextElemStripped = regexprep(nextElem, ['[', openingBracket, closingBracket, ']'], '');

                            if MBeautifier.ContinuationFormatting.isContinueToken(nextElemStripped, tokenStruct) ...
                                    && numel(elementsCell) > elemInd + 1
                                nextElem = strtrim(elementsCell{elemInd+2});
                                nextElemStripped = regexprep(nextElem, ['[', openingBracket, closingBracket, ']'], '');
                            end

                            if strcmp(openingBracket, '[')
                                if MBeautifier.ContinuationFormatting.isContinueToken(currElem, tokenStruct)
                                    if inlineMatrix
                                        elementsCell{elemInd} = '';
                                        continue;
                                    else
                                        currElem = contTokenStructMatrix.Token;
                                    end
                                else

                                end
                                addCommas = configuration.addCommasToMatrices();
                            else
                                addCommas = configuration.addCommasToCellArrays();
                                if MBeautifier.ContinuationFormatting.isContinueToken(currElem, tokenStruct)

                                    if inlineCurly
                                        elementsCell{elemInd} = '';
                                        continue;
                                    else
                                        currElem = contTokenStructCurly.Token;
                                    end
                                end
                            end


                            % Handle space between unary operator and operand
                            % Detect if there is a potential unary operator
                            % and determine if it is the beginning of an
                            % expression
                            lastChar = currElem(end);
                            if lastChar == '-' || lastChar == '+' || lastChar == '~'
                                prevChar = [];
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
                                if isempty(prevChar) || prevChar == ','
                                    currElem = horzcat(currElem, nextElem); %#ok<AGROW>
                                    currElemStripped = regexprep(currElem, ['[', openingBracket, closingBracket, ']'], '');
                                    elementsCell{elemInd+1} = '';
                                    if numel(elementsCell) > elemInd + 1
                                        nextElem = strtrim(elementsCell{elemInd+2});
                                        nextElemStripped = regexprep(nextElem, ['[', openingBracket, closingBracket, ']'], '');
                                    else
                                        elementsCell{elemInd} = currElem;
                                        break
                                    end
                                end
                            end

                            currElem = strtrim(formatElement(currElem, doIndexing, contType, true));
                            numNext = numel(nextElemStripped);

                            if ~addCommas || ...
                                    isempty(currElem) || ...
                                    strcmp(currElem(end), ',') || ...
                                    strcmp(currElem(end), ';') || ...
                                    isInCurlyBracket || ...
                                    MBeautifier.ContinuationFormatting.isContinueToken(currElem, tokenStruct) || ...
                                    any(strcmp(currElemStripped, operatorArray)) || ...
                                    any(strcmp(currElemStripped(end), operatorArray)) || ...
                                    (numNext >= 1 && any(strcmp(nextElemStripped(1), nonUnaryOperatorArray1))) || ...
                                    (numNext > 1 && any(strcmp(nextElemStripped(1:2), nonUnaryOperatorArray2))) || ...
                                    (numNext == 1 && any(strcmp(nextElemStripped, operatorArray))) || ...
                                    numel(regexp(currElemStripped, '^@#MBeauty_ArrayToken_\d+#$'))

                                elementsCell{elemInd} = [currElem, ' '];
                            else
                                elementsCell{elemInd} = [currElem, commaToken];
                            end
                        end
                        elementsCell(cellfun('isempty', elementsCell)) = [];

                        if ~isempty(elementsCell)
                            elementsCell{end} = strtrim(formatElement(elementsCell{end}, doIndexing, contType, true));
                        end
                        strNew = [openingBracket, elementsCell{:}, closingBracket];
                    end
                else
                    strNew = strtrim(str);
                    strNew = [strNew(1), strtrim(formatElement(strNew(2:end-1), doIndexing, contType, true)), strNew(end)];
                end

                datacell = cell(1, 3);
                if containerBorderIndexes{indexes(1), 1} == 1
                    datacell{1} = '';
                else

                    datacell{1} = data(1:containerBorderIndexes{indexes(1), 1}-1);
                    if isContainerIndexing
                        if isWhitespaceDelimiter && datacell{1}(end) == ' '
                            datacell{1} = [strtrim(datacell{1}), ' '];
                        else
                            datacell{1} = strtrim(datacell{1});
                        end
                    elseif preceedingKeyWord
                        datacell{1} = strtrim(datacell{1});
                        datacell{1} = [datacell{1}, ' '];
                    end
                end

                if containerBorderIndexes{indexes(2), 1} == numel(data)
                    datacell{end} = '';
                else
                    datacell{end} = data(containerBorderIndexes{indexes(2), 1}+1:end);
                end

                idAsStr = num2str(id);
                idStr = [repmat('0', 1, 5-numel(idAsStr)), idAsStr];
                tokenOfCUrElem = ['#MBeauty_ArrayToken_', idStr, '#'];
                arrayMap(tokenOfCUrElem) = strNew;
                id = id + 1;
                datacell{2} = tokenOfCUrElem;
                data = horzcat(datacell{:});

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
