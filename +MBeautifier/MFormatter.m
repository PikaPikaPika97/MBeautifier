classdef MFormatter < handle
    % Performs the actual code formatting. Should not be used directly but only by MBeautify.

    properties (Access = private)
        Configuration;
        AllOperators;

        DirectiveDirector;
        StringMemory;

        % Properties used during the formatting
        BlockCommentDepth;
        IsInBlockComment;

        MatrixIndexingOperatorPadding;
        CellArrayIndexingOperatorPadding;
    end

    properties (Access = private, Constant)
        TokenStruct = MBeautifier.MFormatter.getTokenStruct();
    end

    methods
        function obj = MFormatter(configuration)
            % Creates a new formatter using the passed configuration.

            obj.Configuration = configuration;

            obj.MatrixIndexingOperatorPadding = configuration.specialRule('MatrixIndexing_ArithmeticOperatorPadding').ValueAsDouble;
            obj.CellArrayIndexingOperatorPadding = configuration.specialRule('CellArrayIndexing_ArithmeticOperatorPadding').ValueAsDouble;

            % Init run-time members
            obj.StringMemory = [];
            obj.BlockCommentDepth = 0;
            obj.IsInBlockComment = false;
            obj.AllOperators = configuration.operatorCharacters();
        end

        function formattedSource = performFormatting(obj, source)
            % Performs formatting on the specified source.

            obj.BlockCommentDepth = 0;
            obj.IsInBlockComment = false;
            obj.DirectiveDirector = MBeautifier.DirectiveDirector();

            options = obj.createFormattingOptions(source);
            state = obj.createFormattingRunState(numel(options.textArray));
            outputBuffer = cell(1, options.initialOutputCapacity);
            outputCount = 0;

            for j = 1:numel(options.textArray)
                line = options.textArray{j};
                [state, outputBuffer, outputCount] = ...
                    obj.processSourceLine(line, state, options, outputBuffer, outputCount);
            end

            replacedTextArray = obj.finalizeOutputEntries(outputBuffer(1:outputCount), options);
            formattedSource = [replacedTextArray{:}];
        end
    end

    methods (Access = private, Static)
        function textArray = handleStartingEmptyLines(textArray, neededEmptyLineCount)
            followingNewLines = MBeautifier.MFormatter.getFollowingNewlineCount(textArray);

            newLineDelta = neededEmptyLineCount - followingNewLines;

            if newLineDelta < 0
                textArray(1:abs(newLineDelta)) = [];
            elseif newLineDelta > 0
                textArray = [repmat({MBeautifier.Constants.NewLine}, 1, newLineDelta), textArray];
            end
        end

        function count = getFollowingNewlineCount(textArray)
            count = 0;
            for i = 1:numel(textArray)
                if isempty(strtrim(textArray{i}))
                    count = count + 1;
                else
                    return;
                end
            end
        end

        function textArray = handleTrailingEmptyLines(textArray, neededEmptyLineCount)
            precedingNewLines = MBeautifier.MFormatter.getPrecedingNewlineCount(textArray);

            newLineDelta = neededEmptyLineCount - precedingNewLines;

            if newLineDelta < 0
                for i = 1:abs(newLineDelta)
                    textArray(end) = [];
                end
            elseif newLineDelta > 0
                textArray = [textArray, repmat({MBeautifier.Constants.NewLine}, 1, newLineDelta)];
            end
        end

        function count = getPrecedingNewlineCount(textArray)
            count = 0;
            for i = numel(textArray):-1:1
                if isempty(strtrim(textArray{i}))
                    count = count + 1;
                else
                    if count > 0
                        count = count+1;
                    end
                    return;
                end
            end
        end

        function outStr = joinString(cellStr, delim)
            if isempty(cellStr)
                outStr = '';
                return;
            end

            outStr = strjoin(cellStr, delim);
        end

        function tokenStructs = getTokenStruct()
            % Returns the tokens used in replacement.

            % Persistent variable to serve as cache
            persistent tokenStructStored;
            if isempty(tokenStructStored)
                % MBD:Format:Off
                tokenStructs = struct();
                tokenStructs.ContinueToken = newStruct('...', '#MBeutyCont#');
                tokenStructs.ContinueMatrixToken = newStruct('...', '#MBeutyContMatrix#');
                tokenStructs.ContinueCurlyToken = newStruct('...', '#MBeutyContCurly#');
                tokenStructs.ArrayElementToken = newStruct('', '#MBeutyArrayElement#');
                tokenStructs.TransposeToken = newStruct('''', '#MBeutyTransp#');
                tokenStructs.NonConjTransposeToken = newStruct('.''', '#MBeutyNonConjTransp#');
                tokenStructs.NormNotationPlus = newStruct('+', '#MBeautifier_OP_NormNotationPlus');
                tokenStructs.NormNotationMinus = newStruct('-', '#MBeautifier_OP_NormNotationMinus');
                tokenStructs.UnaryPlus = newStruct('+', '#MBeautifier_OP_UnaryPlus');
                tokenStructs.UnaryMinus = newStruct('-', '#MBeautifier_OP_UnaryMinus');
                % MBeautifierDirective:Format:On
                tokenStructStored = tokenStructs;
            else
                tokenStructs = tokenStructStored;
            end

            function retStruct = newStruct(storedValue, replacementString)
                retStruct = struct('StoredValue', storedValue, 'Token', replacementString);
            end
        end

        function code = restoreTransponations(code)
            % Restores transponation tokens to original transponation signs.

            trnspTokStruct = MBeautifier.MFormatter.TokenStruct.TransposeToken;
            nonConjTrnspTokStruct = MBeautifier.MFormatter.TokenStruct.NonConjTransposeToken;

            code = regexprep(code, trnspTokStruct.Token, trnspTokStruct.StoredValue);
            code = regexprep(code, nonConjTrnspTokStruct.Token, nonConjTrnspTokStruct.StoredValue);
        end

        function actCode = replaceTransponations(actCode, token)
            % Replaces transponation signs in the code with tokens.

            if nargin < 2
                trnspTok = MBeautifier.MFormatter.TokenStruct.TransposeToken.Token;
                nonConjTrnspTok = MBeautifier.MFormatter.TokenStruct.NonConjTransposeToken.Token;
            else
                trnspTok = token;
                nonConjTrnspTok = [token, token];
            end

            charsIndicateTranspose = '[a-zA-Z0-9\)\]\}\.]';

            tempParts = cell(1, max(1, numel(actCode) * 2));
            partCount = 0;
            lastOutputChar = '';
            isLastCharDot = false;
            isLastCharTransp = false;
            isInCharStr = false;
            isInDblQuoteStr = false;

            for iStr = 1:numel(actCode)
                actChar = actCode(iStr);

                if isequal(actChar, '"') && ~isInCharStr
                    isInDblQuoteStr = ~isInDblQuoteStr;
                end

                if isequal(actChar, '''')
                    % .' => NonConj transpose
                    if isLastCharDot
                        [tempParts, partCount] = MBeautifier.MFormatter.trimLastOutputChar(tempParts, partCount);
                        [tempParts, partCount, lastOutputChar] = MBeautifier.MFormatter.appendTextPart( ...
                            tempParts, partCount, nonConjTrnspTok);
                        isLastCharTransp = true;
                    else
                        if isLastCharTransp
                            [tempParts, partCount, lastOutputChar] = MBeautifier.MFormatter.appendTextPart( ...
                                tempParts, partCount, trnspTok);
                        else
                            if isInDblQuoteStr
                                [tempParts, partCount, lastOutputChar] = MBeautifier.MFormatter.appendTextPart( ...
                                    tempParts, partCount, actChar);
                                isLastCharTransp = false;
                            elseif partCount > 0 && ~isInCharStr ...
                                    && ~isempty(regexp(lastOutputChar, charsIndicateTranspose, 'once'))
                                [tempParts, partCount, lastOutputChar] = MBeautifier.MFormatter.appendTextPart( ...
                                    tempParts, partCount, trnspTok);
                                isLastCharTransp = true;
                            else
                                [tempParts, partCount, lastOutputChar] = MBeautifier.MFormatter.appendTextPart( ...
                                    tempParts, partCount, actChar);
                                isInCharStr = ~isInCharStr;
                                isLastCharTransp = false;
                            end
                        end
                    end

                    isLastCharDot = false;
                elseif isequal(actChar, '.') && ~isInCharStr
                    isLastCharDot = true;
                    [tempParts, partCount, lastOutputChar] = MBeautifier.MFormatter.appendTextPart( ...
                        tempParts, partCount, actChar);
                    isLastCharTransp = false;
                else
                    isLastCharDot = false;
                    [tempParts, partCount, lastOutputChar] = MBeautifier.MFormatter.appendTextPart( ...
                        tempParts, partCount, actChar);
                    isLastCharTransp = false;
                end
            end
            if partCount == 0
                actCode = '';
            else
                actCode = [tempParts{1:partCount}];
            end
        end
    end

    methods (Access = private)
        function options = createFormattingOptions(obj, source)
            newLine = MBeautifier.Constants.NewLine;
            options = struct();
            options.newLine = newLine;
            options.textArray = regexp(source, newLine, 'split');
            options.maximalNewLines = obj.Configuration.specialRule('MaximalNewLines').ValueAsDouble;
            options.sectionPrecedingNewlines = obj.Configuration.specialRule('SectionPrecedingNewlineCount').ValueAsDouble;
            options.formatSectionPrecedingNewlines = options.sectionPrecedingNewlines >= 0;
            options.sectionTrailingNewlines = obj.Configuration.specialRule('SectionTrailingNewlineCount').ValueAsDouble;
            options.formatSectionTrailingNewlines = options.sectionTrailingNewlines >= 0;
            options.startingNewlines = obj.Configuration.specialRule('StartingNewlineCount').ValueAsDouble;
            options.formatStartingNewlines = options.startingNewlines >= 0;
            options.endingNewlines = obj.Configuration.specialRule('EndingNewlineCount').ValueAsDouble;
            options.formatEndingNewlines = options.endingNewlines >= 0;
            options.contTokenStruct = MBeautifier.MFormatter.TokenStruct.ContinueToken;
            options.initialOutputCapacity = max(16, numel(options.textArray) * 4 + 8);
        end

        function state = createFormattingRunState(~, lineCount)
            state = struct( ...
                'isFormattingOff', false, ...
                'isInContinousLine', false, ...
                'containerDepth', 0, ...
                'continuousLines', {cell(max(1, lineCount), 2)}, ...
                'continuousLineCount', 0, ...
                'isSectionSeparator', false, ...
                'isInArgumentsBlock', false, ...
                'nNewLinesFound', 0);
        end

        function [state, outputBuffer, outputCount] = processSourceLine(obj, line, state, options, outputBuffer, outputCount)
            % Directive changes only affect standalone code lines outside block comments.
            if ~(state.isInContinousLine || obj.IsInBlockComment)
                directiveChange = obj.DirectiveDirector.updateFromLine(line);
                if ~isequal(directiveChange.Type, MBeautifier.DirectiveChangeType.NONE)
                    switch lower(directiveChange.DirectiveName)
                        case 'format'
                            if isequal(directiveChange.Type, MBeautifier.DirectiveChangeType.REMOVED)
                                state.isFormattingOff = false;
                            elseif isequal(directiveChange.Type, MBeautifier.DirectiveChangeType.ADDED) ...
                                    || isequal(directiveChange.Type, MBeautifier.DirectiveChangeType.CHANGED)
                                state.isFormattingOff = numel(directiveChange.Directive.Values) > 0 ...
                                    && strcmpi(directiveChange.Directive.Values{1}, 'off');
                            end
                    end
                end
            end

            if state.isFormattingOff
                [outputBuffer, outputCount] = MBeautifier.MFormatter.appendOutputEntries( ...
                    outputBuffer, outputCount, {line, options.newLine});
                return;
            end

            [state, outputBuffer, outputCount, wasHandled] = ...
                obj.processBlankLine(line, state, options, outputBuffer, outputCount);
            if wasHandled
                return;
            end

            [state, outputBuffer, outputCount] = ...
                obj.processFormattedLine(line, state, options, outputBuffer, outputCount);
        end

        function [state, outputBuffer, outputCount, wasHandled] = processBlankLine(~, line, state, options, outputBuffer, outputCount)
            wasHandled = false;

            if isempty(strtrim(line))
                state.nNewLinesFound = state.nNewLinesFound + 1;

                if state.nNewLinesFound > options.maximalNewLines || ...
                        (options.formatSectionTrailingNewlines && state.isSectionSeparator ...
                        && state.nNewLinesFound > options.sectionTrailingNewlines)
                    wasHandled = true;
                    return;
                end

                [outputBuffer, outputCount] = MBeautifier.MFormatter.appendOutputEntries( ...
                    outputBuffer, outputCount, {options.newLine});
                wasHandled = true;
                return;
            end

            if state.isSectionSeparator && options.formatSectionTrailingNewlines ...
                    && state.nNewLinesFound < options.sectionTrailingNewlines
                missingNewLines = options.sectionTrailingNewlines - state.nNewLinesFound;
                [outputBuffer, outputCount] = MBeautifier.MFormatter.appendRepeatedEntry( ...
                    outputBuffer, outputCount, options.newLine, missingNewLines);
            end

            state.nNewLinesFound = 0;
        end

        function [state, outputBuffer, outputCount] = processFormattedLine(obj, line, state, options, outputBuffer, outputCount)
            [actCode, actComment, splittingPos, state.isSectionSeparator] = obj.findComment(line);
            trimmedCode = strtrim(actCode);
            currentContext = obj.classifyFormattingContext(trimmedCode, state.isInArgumentsBlock);
            actComment = obj.adjustInlineCommentSpacing(actCode, actComment);

            if state.isSectionSeparator && options.formatSectionPrecedingNewlines
                currentEntries = MBeautifier.MFormatter.handleTrailingEmptyLines( ...
                    outputBuffer(1:outputCount), options.sectionPrecedingNewlines);
                [outputBuffer, outputCount] = MBeautifier.MFormatter.replaceOutputEntries( ...
                    outputBuffer, currentEntries);
            end

            if isempty(trimmedCode)
                if isequal(splittingPos, 1) && state.isInContinousLine
                    state = obj.appendContinuousLine(state, actCode, actComment);
                    return;
                end
                actCodeFinal = '';
            else
                [state, actCode, trimmedCode, wasDeferred] = ...
                    obj.prepareLineForFormatting(actCode, actComment, trimmedCode, splittingPos, state);
                if wasDeferred
                    return;
                end

                if state.isInContinousLine
                    contLineArray = state.continuousLines(1:state.continuousLineCount, :);
                    line = obj.formatContinuousLine(contLineArray, actComment, options.contTokenStruct, options.newLine);
                    [outputBuffer, outputCount] = MBeautifier.MFormatter.appendOutputEntries( ...
                        outputBuffer, outputCount, {[line, options.newLine]});
                    state.continuousLineCount = 0;
                    state.isInContinousLine = false;
                    return;
                end

                actCodeFinal = obj.formatCodeByContext(actCode, currentContext);
            end

            line = obj.buildFormattedLine(actCodeFinal, actComment);
            [outputBuffer, outputCount] = MBeautifier.MFormatter.appendOutputEntries( ...
                outputBuffer, outputCount, {[line, options.newLine]});
            state.isInArgumentsBlock = obj.updateArgumentsBlockState(trimmedCode, state.isInArgumentsBlock);
        end

        function [state, actCode, trimmedCode, wasDeferred] = prepareLineForFormatting(obj, actCode, actComment, trimmedCode, splittingPos, state)
            wasDeferred = false;

            if obj.shouldPreserveContextAwareSourceLine(trimmedCode)
                actCode = trimmedCode;
                return;
            end

            state.containerDepth = state.containerDepth + obj.calculateContainerDepthDeltaOfLine(trimmedCode);
            actCode = obj.appendContinuationMarkerIfNeeded(actCode, trimmedCode, state.containerDepth);
            trimmedCode = strtrim(actCode);

            if obj.shouldAccumulateContinuousLine(trimmedCode, splittingPos, state.isInContinousLine)
                state.isInContinousLine = true;
                state = obj.appendContinuousLine(state, actCode, actComment);
                wasDeferred = true;
                return;
            end

            if state.isInContinousLine
                state = obj.appendContinuousLine(state, actCode, actComment);
            end
        end

        function actComment = adjustInlineCommentSpacing(obj, actCode, actComment)
            actComment = MBeautifier.LineFormattingStages.preserveInlineCommentSpacing( ...
                actCode, actComment, obj.Configuration.inlineCommentSpacingStrategy());
        end

        function actCode = appendContinuationMarkerIfNeeded(~, actCode, trimmedCode, containerDepth)
            % Auto append "..." to the lines of continuous containers.
            if ~containerDepth || (numel(trimmedCode) >= 3 && strcmp(trimmedCode(end-2:end), '...'))
                return;
            end

            if strcmp(trimmedCode(end), ',') || strcmp(trimmedCode(end), ';')
                actCode = [trimmedCode, ' ...'];
            else
                actCode = [actCode, '; ...'];
            end
        end

        function tf = shouldAccumulateContinuousLine(~, trimmedCode, splittingPos, isInContinousLine)
            tf = (numel(trimmedCode) >= 3 && strcmp(trimmedCode(end-2:end), '...')) ...
                || (isequal(splittingPos, 1) && isInContinousLine);
        end

        function state = appendContinuousLine(~, state, actCode, actComment)
            state.continuousLineCount = state.continuousLineCount + 1;
            state.continuousLines{state.continuousLineCount, 1} = actCode;
            state.continuousLines{state.continuousLineCount, 2} = actComment;
        end

        function actCodeFinal = formatCodeByContext(obj, actCode, currentContext)
            if strcmp(currentContext, 'argumentsDeclaration')
                actCodeFinal = obj.formatDeclarationLine(actCode);
            else
                actCodeFinal = obj.performReplacements(actCode);
            end
        end

        function replacedTextArray = finalizeOutputEntries(~, replacedTextArray, options)
            % The last new-line must be removed: inner new-lines are removed by the split, the last one is an additional one.
            if ~isempty(replacedTextArray) && ~isempty(strtrim(replacedTextArray{end}))
                replacedTextArray{end} = strtrim(replacedTextArray{end});
            end

            if options.formatStartingNewlines
                replacedTextArray = MBeautifier.MFormatter.handleStartingEmptyLines( ...
                    replacedTextArray, options.startingNewlines);
            end

            if options.formatEndingNewlines
                replacedTextArray = MBeautifier.MFormatter.handleTrailingEmptyLines( ...
                    replacedTextArray, options.endingNewlines);
            end
        end

        function actCodeTemp = replaceStrings(obj, actCode)
            % Replaces strings in the code with string tokens memorizing the original text

            obj.StringMemory = MBeautifier.StringMemory.fromCodeLine(actCode);
            actCodeTemp = obj.StringMemory.MemorizedCodeLine;
        end

        function actCodeFinal = restoreStrings(obj, actCodeTemp)
            % Replaces string tokens with the original string from the memory

            for i = 1:numel(obj.StringMemory.Mementos)
                actCodeTemp = regexprep(actCodeTemp, MBeautifier.Constants.StringToken, ...
                    regexptranslate('escape', obj.StringMemory.Mementos{i}.Text), 'once');
            end

            actCodeFinal = actCodeTemp;
        end

        function code = performReplacements(obj, code)
            % Wrapper around code replacement: Replace transponations -> replace strings -> perform other replacements
            % (operators, containers, ...) -> restore strings -> restore transponations.

            code = obj.replaceStrings(obj.replaceTransponations(code));
            code = obj.performFormattingSingleLine(code, false, '', false);
            code = obj.restoreTransponations(obj.restoreStrings(code));
        end

        function [actCode, actComment, splittingPos, isSectionSeparator] = findComment(obj, line)
            % Splits a continous line into code and comment parts.
            analysis = MBeautifier.SourceLine.analyze( ...
                line, obj.IsInBlockComment, obj.BlockCommentDepth);

            actCode = analysis.Code;
            actComment = analysis.Comment;
            splittingPos = analysis.SplittingPosition;
            isSectionSeparator = analysis.IsSectionSeparator;
            obj.IsInBlockComment = analysis.IsInBlockComment;
            obj.BlockCommentDepth = analysis.BlockCommentDepth;
        end

        function data = performFormattingSingleLine(obj, data, doIndexing, contType, isContainerElement)
            % Performs formatting on a code snippet, where the strings and transponations are already replaced:
            % operator, container formatting

            if isempty(data)
                return;
            end

            if nargin < 3
                doIndexing = false;
            end

            if nargin < 4
                contType = '';
            end

            operatorPaddingRules = obj.Configuration.operatorPaddingRuleNames();
            % At this point, the data contains one line of code, but all user-defined strings enclosed in '' are replaced by #MBeutyString#

            % Old-style function calls, such as 'subplot 211' or 'disp Hello World' -> return unchanged
            if numel(regexp(data, '^[a-zA-Z0-9_]+\s+[^(=]'))

                splitData = regexp(strtrim(data), ' ', 'split');
                % The first elemen is not a keyword and does not exist (function on the path)
                if numel(splitData) && ~any(strcmp(splitData{1}, iskeyword())) && exist(splitData{1}) %#ok<EXIST>
                    return
                end
            end

            % Process matrixes and cell arrays
            % All containers are processed element wised. The replaced containers are placed into a map where the key is a token
            % inserted to the original data
            [data, arrayMapCell] = obj.replaceContainer(data);

            if obj.Configuration.specialRule('InlineContinousLines').ValueAsDouble
                data = regexprep(data, MBeautifier.MFormatter.TokenStruct.ContinueToken.Token, '');
            end

            % Convert all operators like + * == etc to #MBeautifier_OP_whatever# tokens
            opBuffer = cell(1, numel(operatorPaddingRules));
            opBufferCount = 0;
            operatorList = obj.AllOperators;
            operatorAppearance = regexp(data, operatorList);

            if ~isempty([operatorAppearance{:}])
                for iOpConf = 1:numel(operatorPaddingRules)
                    currField = operatorPaddingRules{iOpConf};
                    currOpStruct = obj.Configuration.operatorPaddingRule(currField);
                    dataNew = regexprep(data, ['\s*', currOpStruct.ValueFrom, '\s*'], currOpStruct.Token);
                    if ~strcmp(data, dataNew)
                        opBufferCount = opBufferCount + 1;
                        opBuffer{opBufferCount} = currField;
                    end
                    data = dataNew;
                end
            end
            opBuffer = opBuffer(1:opBufferCount);

            % Remove all duplicate space
            data = regexprep(data, '\s+', ' ');
            keywords = iskeyword();

            % Handle special + and - cases:
            % 	- unary plus/minus, such as in (+1): replace #MBeautifier_OP_Plus/Minus# by #MBeautifier_OP_UnaryPlus/Minus#
            %   - normalized number format, such as 7e-3: replace #MBeautifier_OP_Plus/Minus# by #MBeautifier_OP_NormNotation_Plus/Minus#
            % Then convert UnaryPlus tokens to '+' signs same for minus)
            plusMinusCell = {'Plus', 'Minus'};
            unaryPlusOperatorPresent = false;
            unaryMinusOperatorPresent = false;
            normPlusOperatorPresent = false;
            normMinusOperatorPresent = false;

            for iOpConf = 1:numel(plusMinusCell)

                if any(strcmp(plusMinusCell{iOpConf}, opBuffer))

                    currField = plusMinusCell{iOpConf};
                    isPlus = isequal(currField, 'Plus');

                    opToken = obj.Configuration.operatorPaddingRule(currField).Token;

                    splittedData = regexp(data, opToken, 'split');

                    posMatch = ['(', MBeautifier.MFormatter.joinString({'[0-9a-zA-Z_)}\]\.]', ...
                        MBeautifier.MFormatter.TokenStruct.TransposeToken.Token, ...
                        MBeautifier.MFormatter.TokenStruct.NonConjTransposeToken.Token, ...
                        MBeautifier.Constants.StringToken, ...
                        '#MBeauty_ArrayToken_\d+#'}, '|'), ')$'];
                    negMatch = [obj.Configuration.operatorPaddingRule('At').Token, ...
                        '#MBeauty_ArrayToken_\d+#$'];
                    keywordMatch = ['(?=^|\s)(', MBeautifier.MFormatter.joinString(keywords', '|'), ')$'];

                    replaceTokens = cell(1, max(0, numel(splittedData) - 1));
                    replaceTokenCount = 0;
                    for iSplit = 1:numel(splittedData) - 1
                        beforeItem = strtrim(splittedData{iSplit});
                        if ~isempty(beforeItem) && ...
                                numel(regexp(beforeItem, posMatch)) && ...
                                ~numel(regexp(beforeItem, negMatch)) && ...
                                (doIndexing || ~numel(regexp(beforeItem, keywordMatch)))
                            % + or - is a binary operator after:
                            %    - numbers [0-9.],
                            %    - variable names [a-zA-Z0-9_] or
                            %    - closing brackets )}]
                            %    - transpose signs ', here represented as #MBeutyTransp#
                            %    - non-conjugate transpose signs .', here represented as #MBeutyNonConjTransp#
                            %    - Strings, here represented as #MBeutyString#
                            %    - keywords
                            % but not after an anonymous function

                            % Special treatment for E: 7E-3 or 7e+4 normalized notation
                            % In this case the + and - signs are not operators so shoud be skipped
                            if numel(beforeItem) > 1 && strcmpi(beforeItem(end), 'e') && numel(regexp(beforeItem(end-1), '[0-9.]'))
                                if isPlus
                                    replaceTokenCount = replaceTokenCount + 1;
                                    replaceTokens{replaceTokenCount} = MBeautifier.MFormatter.TokenStruct.NormNotationPlus.Token;
                                    normPlusOperatorPresent = true;
                                else
                                    replaceTokenCount = replaceTokenCount + 1;
                                    replaceTokens{replaceTokenCount} = MBeautifier.MFormatter.TokenStruct.NormNotationMinus.Token;
                                    normMinusOperatorPresent = true;
                                end
                            else
                                replaceTokenCount = replaceTokenCount + 1;
                                replaceTokens{replaceTokenCount} = opToken;
                            end
                        else
                            if isPlus
                                replaceTokenCount = replaceTokenCount + 1;
                                replaceTokens{replaceTokenCount} = MBeautifier.MFormatter.TokenStruct.UnaryPlus.Token;
                                unaryPlusOperatorPresent = true;
                            else
                                replaceTokenCount = replaceTokenCount + 1;
                                replaceTokens{replaceTokenCount} = MBeautifier.MFormatter.TokenStruct.UnaryMinus.Token;
                                unaryMinusOperatorPresent = true;
                            end
                        end
                    end

                    replaceTokens = replaceTokens(1:replaceTokenCount);
                    replacedSplittedData = cell(1, numel(replaceTokens) + numel(splittedData));
                    tokenIndex = 1;
                    for iSplit = 1:numel(splittedData)
                        replacedSplittedData{iSplit*2-1} = splittedData{iSplit};
                        if iSplit < numel(splittedData)
                            replacedSplittedData{iSplit*2} = replaceTokens{tokenIndex};
                        end
                        tokenIndex = tokenIndex + 1;
                    end
                    data = [replacedSplittedData{:}];
                end
            end

            %%
            % At this point the data is in a completely tokenized representation, e.g.'x#MBeautifier_OP_Plus#y' instead of the 'x + y'.
            % Now go backwards and replace the tokens by the real operators

            % Special tokens: Unary Plus/Minus, Normalized Number Format
            % Performance tweak: only if there were any unary or norm operators
            if unaryPlusOperatorPresent
                data = regexprep(data, ['\s*', MBeautifier.MFormatter.TokenStruct.UnaryPlus.Token, '\s*'], [' ', MBeautifier.MFormatter.TokenStruct.UnaryPlus.StoredValue]);
            end
            if unaryMinusOperatorPresent
                data = regexprep(data, ['\s*', MBeautifier.MFormatter.TokenStruct.UnaryMinus.Token, '\s*'], [' ', MBeautifier.MFormatter.TokenStruct.UnaryMinus.StoredValue]);
            end
            if normPlusOperatorPresent
                data = regexprep(data, ['\s*', MBeautifier.MFormatter.TokenStruct.NormNotationPlus.Token, '\s*'], MBeautifier.MFormatter.TokenStruct.NormNotationPlus.StoredValue);
            end
            if normMinusOperatorPresent
                data = regexprep(data, ['\s*', MBeautifier.MFormatter.TokenStruct.NormNotationMinus.Token, '\s*'], MBeautifier.MFormatter.TokenStruct.NormNotationMinus.StoredValue);
            end

            % Replace all other operators
            for iOpConf = 1:numel(operatorPaddingRules)
                currField = operatorPaddingRules{iOpConf};

                if any(strcmp(currField, opBuffer))
                    currOpStruct = obj.Configuration.operatorPaddingRule(currField);

                    valTo = currOpStruct.ValueTo;
                    if doIndexing && ~isempty(contType) && numel(regexp(currOpStruct.ValueFrom, '\+|\-|\/|\*'))
                        if strcmp(contType, 'matrix')
                            replacementPattern = currOpStruct.matrixIndexingReplacementPattern(obj.MatrixIndexingOperatorPadding);
                            if ~obj.MatrixIndexingOperatorPadding
                                valTo = strrep(valTo, ' ', '');
                            end

                        elseif strcmp(contType, 'cell')
                            replacementPattern = currOpStruct.cellArrayIndexingReplacementPattern(obj.CellArrayIndexingOperatorPadding);
                            if ~obj.CellArrayIndexingOperatorPadding
                                valTo = strrep(valTo, ' ', '');
                            end
                        end
                    else
                        replacementPattern = currOpStruct.ReplacementPattern;
                    end

                    tokenizedReplaceString = strrep(valTo, ' ', MBeautifier.Constants.WhiteSpaceToken);

                    % Replace only the amount of whitespace tokens that are actually needed by the operator rule
                    data = regexprep(data, replacementPattern, tokenizedReplaceString);
                end
            end

            if ~isContainerElement
                data = obj.applyStatementBreakStrategy(data);
            end

            data = regexprep(data, MBeautifier.Constants.WhiteSpaceToken, ' ');

            data = regexprep(data, ' \)', ')');
            data = regexprep(data, ' \]', ']');
            data = regexprep(data, '\( ', '(');
            data = regexprep(data, '\[ ', '[');

            % Keyword formatting
            keywordRules = obj.Configuration.keywordPaddingRules();
            for i = 1:numel(keywordRules)
                rule = keywordRules{i};
                data = regexprep(data, ['(?<=\b|^)', rule.Keyword, '\s*(?=#MBeauty_ArrayToken_\d+#)'], rule.ReplaceTo);
            end

            % Restore containers
            data = obj.restoreContainers(data, arrayMapCell);

            % Fix semicolon whitespace at end of line
            data = regexprep(data, '\s+;\s*$', ';');
            data = strtrim(data);
        end

        function line = formatContinuousLine(obj, contLineArray, actComment, contTokenStruct, newLine)
            lineCount = size(contLineArray, 1);
            lineParts = cell(1, lineCount);
            for iLine = 1:lineCount - 1
                tempRow = strtrim(contLineArray{iLine, 1});
                tempRow = [tempRow(1:end-3), [' ', contTokenStruct.Token, ' ']];
                tempRow = regexprep(tempRow, ['\s+', contTokenStruct.Token, '\s+'], [' ', contTokenStruct.Token, ' ']);
                lineParts{iLine} = tempRow;
            end
            lineParts{lineCount} = contLineArray{end, 1};
            replacedLines = [lineParts{:}];

            actCodeFinal = obj.performReplacements(replacedLines);
            [startIndices, endIndices] = regexp(actCodeFinal, '\s*#MBeutyCont(|Matrix|Curly)#');
            if isempty(startIndices)
                line = obj.buildInlinedContinuousLine(contLineArray, actCodeFinal, newLine);
                return;
            end

            line = obj.rebuildContinuousLine(contLineArray, actComment, actCodeFinal, startIndices, endIndices, contTokenStruct, newLine);
        end

        function line = buildInlinedContinuousLine(obj, contLineArray, actCodeFinal, newLine)
            fullComment = obj.buildContinousLineCommentAsPrecedingLines(contLineArray);
            if isempty(fullComment)
                line = actCodeFinal;
            else
                line = [fullComment, newLine, actCodeFinal];
            end

            lastComment = contLineArray{end, 2};
            if ~isempty(strtrim(lastComment))
                if ~numel(regexp(lastComment, '^\s*%'))
                    lastComment = ['% ', lastComment];
                end
                line = [line, ' ', lastComment];
            end
        end

        function line = rebuildContinuousLine(obj, contLineArray, actComment, actCodeFinal, startIndices, endIndices, contTokenStruct, newLine)
            linesAreMathing = numel(startIndices) == size(contLineArray, 1) - 1;

            lineParts = cell(1, numel(startIndices) + 1);
            linePartCount = 0;
            lastEndIndex = 0;
            for iMatch = 1:numel(startIndices)
                partBefore = strtrim(actCodeFinal(lastEndIndex+1:startIndices(iMatch)-1));
                lastEndIndex = endIndices(iMatch);
                if linesAreMathing
                    linePartCount = linePartCount + 1;
                    lineParts{linePartCount} = [partBefore, [' ', contTokenStruct.StoredValue, ' '], contLineArray{iMatch, 2}, newLine];
                else
                    linePartCount = linePartCount + 1;
                    lineParts{linePartCount} = [partBefore, [' ', contTokenStruct.StoredValue, ' '], newLine];
                end
            end

            if ~linesAreMathing
                fullComment = obj.buildContinousLineCommentAsPrecedingLines(contLineArray);
                if ~isempty(fullComment)
                    linePartCount = linePartCount + 1;
                    lineParts = [{[fullComment, newLine]}, lineParts(1:linePartCount)];
                end
            end

            lineParts{linePartCount+1} = [actCodeFinal(lastEndIndex+1:end), ' ', actComment];
            line = [lineParts{1:linePartCount+1}];
        end

        function tf = isLikelyFunctionCallContainer(~, data, openingIndex)
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

        function line = buildFormattedLine(obj, actCodeFinal, actComment)
            trimmedCode = strtrim(actCodeFinal);
            trimmedComment = strtrim(actComment);

            if isempty(trimmedComment)
                line = trimmedCode;
                return;
            end

            if isempty(trimmedCode)
                line = trimmedComment;
            elseif obj.shouldPreserveInlineCommentSpacing() || obj.IsInBlockComment
                line = [trimmedCode, actComment];
            else
                line = [trimmedCode, ' ', trimmedComment];
            end
        end

        function tf = shouldPreserveInlineCommentSpacing(obj)
            tf = strcmpi(obj.Configuration.inlineCommentSpacingStrategy(), 'Preserve');
        end

        function data = applyStatementBreakStrategy(obj, data)
            if ~obj.hasMultipleStatements(data)
                return;
            end

            strategy = lower(strtrim(obj.Configuration.statementBreakStrategy()));
            switch strategy
                case 'never'
                    return;

                case 'contextaware'
                    if obj.isContextAwareCompactStatement(data)
                        return;
                    end
                    data = obj.splitNonTrailingStatements(data);

                otherwise
                    data = obj.splitNonTrailingStatements(data);
            end
        end

        function tf = isContextAwareCompactStatement(obj, data)
            trimmed = strtrim(data);
            tf = false;

            if isempty(trimmed)
                return;
            end

            if ~obj.hasClosingCompactEnd(trimmed)
                return;
            end

            if obj.startsCompactLoopOrConditional(trimmed)
                tf = true;
                return;
            end

            if obj.isCompactTryCatch(trimmed)
                tf = true;
            end
        end

        function data = splitNonTrailingStatements(~, data)
            data = regexprep(data, ';(?!\s*$)', ';\n');
        end

        function context = classifyFormattingContext(obj, trimmedCode, isInArgumentsBlock)
            context = 'generic';

            if isempty(trimmedCode)
                return;
            end

            if isInArgumentsBlock
                if obj.isArgumentsBlockEnd(trimmedCode)
                    context = 'argumentsEnd';
                elseif obj.isArgumentsDeclarationLine(trimmedCode)
                    context = 'argumentsDeclaration';
                else
                    context = 'argumentsBody';
                end
                return;
            end

            if obj.isArgumentsBlockStart(trimmedCode)
                context = 'argumentsStart';
                return;
            end

            token = regexp(trimmedCode, '^[a-zA-Z]+', 'match', 'once');
            if isempty(token)
                return;
            end

            switch lower(token)
                case 'properties'
                    context = 'propertiesBlock';
                case 'methods'
                    context = 'methodsBlock';
                case 'function'
                    context = 'functionHeader';
                case 'classdef'
                    context = 'classHeader';
            end
        end

        function isInArgumentsBlock = updateArgumentsBlockState(obj, trimmedCode, isInArgumentsBlock)
            if obj.isArgumentsBlockStart(trimmedCode)
                isInArgumentsBlock = true;
            elseif isInArgumentsBlock && obj.isArgumentsBlockEnd(trimmedCode)
                isInArgumentsBlock = false;
            end
        end

        function tf = isArgumentsBlockStart(~, trimmedCode)
            tf = ~isempty(regexp(trimmedCode, '^arguments(\s*\(.*\))?\s*$', 'once'));
        end

        function tf = isArgumentsBlockEnd(~, trimmedCode)
            tf = ~isempty(regexp(trimmedCode, '^end\s*;?\s*$', 'once'));
        end

        function tf = isArgumentsDeclarationLine(obj, trimmedCode)
            tf = ~isempty(regexp(trimmedCode, '^[a-zA-Z]\w*(\.[a-zA-Z]\w*)*', 'once')) ...
                && ~obj.isArgumentsBlockStart(trimmedCode) ...
                && ~obj.isArgumentsBlockEnd(trimmedCode);
        end

        function data = formatDeclarationLine(obj, data)
            [data, wasHandled] = MBeautifier.LineFormattingStages.formatDeclarationLine( ...
                data, obj.Configuration.declarationSpacingStyle());
            if ~wasHandled
                data = obj.performReplacements(data);
            end
        end

        function tf = shouldPreserveContextAwareSourceLine(obj, trimmedCode)
            tf = false;

            if ~strcmpi(obj.Configuration.statementBreakStrategy(), 'ContextAware')
                return;
            end

            if ~obj.hasClosingCompactEnd(trimmedCode) || ~obj.hasMultipleStatements(trimmedCode)
                return;
            end

            if obj.startsCompactLoopOrConditional(trimmedCode)
                tf = true;
                return;
            end

            if obj.isCompactTryCatch(trimmedCode)
                tf = true;
            end
        end

        function ret = calculateContainerDepthDeltaOfLine(obj, code)
            % Calculates the delta of container depth in a single code line.

            % Pre-check for opening and closing brackets: the final delta has to be calculated after the transponations and the
            % strings are replaced, which are time consuming actions
            ret = 0;
            if numel(regexp(code, '{|[')) || numel(regexp(code, '}|]'))
                actCodeTemp = obj.replaceStrings(obj.replaceTransponations(code));
                ret = numel(regexp(actCodeTemp, '{|[')) - numel(regexp(actCodeTemp, '}|]'));
            end
        end

        function [containerBorderIndexes, maxDepth] = calculateContainerDepths(~, data)
            [containerBorderIndexes, maxDepth] = MBeautifier.ContainerScanner.calculateDepths(data);
        end

        function [data, arrayMap] = replaceContainer(obj, data)
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
            contTokenStructMatrix = MBeautifier.MFormatter.TokenStruct.ContinueMatrixToken;
            contTokenStructCurly = MBeautifier.MFormatter.TokenStruct.ContinueCurlyToken;
            commaToken = obj.Configuration.operatorPaddingRule('Comma').Token;

            [containerBorderIndexes, maxDepth] = obj.calculateContainerDepths(data);

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
                        && obj.isLikelyFunctionCallContainer(data, containerBorderIndexes{indexes(1), 1})
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
                str = regexprep(str, '\s+', ' ');
                str = regexprep(str, [openingBracket, '\s+'], openingBracket);
                str = regexprep(str, ['\s+', closingBracket], closingBracket);

                if ~strcmp(openingBracket, '(')
                    if doIndexing
                        strNew = strtrim(str);
                        strNew = [strNew(1), strtrim(obj.performFormattingSingleLine(strNew(2:end-1), doIndexing, contType, true)), strNew(end)];
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
                        inlineMatrix = obj.Configuration.specialRule('InlineContinousLinesInMatrixes').ValueAsDouble;
                        inlineCurly = obj.Configuration.specialRule('InlineContinousLinesInCurlyBracket').ValueAsDouble;
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

                            if obj.isContinueToken(nextElemStripped) && numel(elementsCell) > elemInd + 1
                                nextElem = strtrim(elementsCell{elemInd+2});
                                nextElemStripped = regexprep(nextElem, ['[', openingBracket, closingBracket, ']'], '');
                            end

                            if strcmp(openingBracket, '[')
                                if obj.isContinueToken(currElem)
                                    if inlineMatrix
                                        elementsCell{elemInd} = '';
                                        continue;
                                    else
                                        currElem = contTokenStructMatrix.Token;
                                    end
                                else

                                end
                                addCommas = obj.Configuration.specialRule('AddCommasToMatrices').ValueAsDouble;
                            else
                                addCommas = obj.Configuration.specialRule('AddCommasToCellArrays').ValueAsDouble;
                                if obj.isContinueToken(currElem)

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

                            currElem = strtrim(obj.performFormattingSingleLine(currElem, doIndexing, contType, true));
                            numNext = numel(nextElemStripped);

                            if ~addCommas || ...
                                    isempty(currElem) || ...
                                    strcmp(currElem(end), ',') || ...
                                    strcmp(currElem(end), ';') || ...
                                    isInCurlyBracket || ...
                                    obj.isContinueToken(currElem) || ...
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
                            elementsCell{end} = strtrim(obj.performFormattingSingleLine(elementsCell{end}, doIndexing, contType, true));
                        end
                        strNew = [openingBracket, elementsCell{:}, closingBracket];
                    end
                else
                    strNew = strtrim(str);
                    strNew = [strNew(1), strtrim(obj.performFormattingSingleLine(strNew(2:end-1), doIndexing, contType, true)), strNew(end)];
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

                containerBorderIndexes = obj.calculateContainerDepths(data);
            end
        end

        function data = restoreContainers(obj, data, map)
            % Replaces container tokens with the original container contents.

            arrayTokenList = map.keys();
            if isempty(arrayTokenList)
                return;
            end

            for iKey = numel(arrayTokenList):-1:1
                data = regexprep(data, arrayTokenList{iKey}, regexptranslate('escape', map(arrayTokenList{iKey})));
            end
            obj.Configuration.operatorPaddingRule('Comma').Token;
            data = regexprep(data, obj.Configuration.operatorPaddingRule('Comma').Token, obj.Configuration.operatorPaddingRule('Comma').ValueTo);
        end

        function ret = isContinueToken(obj, element)
            ret = MBeautifier.ContinuationFormatting.isContinueToken(element, obj.TokenStruct);
        end

        function fullComment = buildContinousLineCommentAsPrecedingLines(~, contLineArray)
            fullComment = MBeautifier.ContinuationFormatting.buildCommentAsPrecedingLines(contLineArray);
        end

        function tf = hasMultipleStatements(~, data)
            tf = numel(strfind(data, ';')) > 1;
        end

        function tf = hasClosingCompactEnd(~, trimmedCode)
            tf = ~isempty(regexp(trimmedCode, '(^|[^a-zA-Z0-9_])end\s*;?\s*$', 'once'));
        end

        function tf = startsCompactLoopOrConditional(~, trimmedCode)
            tf = ~isempty(regexp(trimmedCode, '^(if|for|while)($|[^a-zA-Z0-9_])', 'once'));
        end

        function tf = isCompactTryCatch(~, trimmedCode)
            tf = ~isempty(regexp(trimmedCode, '^try($|[^a-zA-Z0-9_])', 'once')) && ...
                ~isempty(regexp(trimmedCode, '(^|[^a-zA-Z0-9_])catch($|[^a-zA-Z0-9_])', 'once'));
        end
    end

    methods (Access = private, Static)
        function [buffer, count] = appendOutputEntries(buffer, count, entries)
            if isempty(entries)
                return;
            end

            neededCount = count + numel(entries);
            if neededCount > numel(buffer)
                newCapacity = max(neededCount, max(16, numel(buffer) * 2));
                buffer{newCapacity} = '';
            end

            buffer(count+1:neededCount) = entries;
            count = neededCount;
        end

        function [buffer, count] = appendRepeatedEntry(buffer, count, entry, repeatCount)
            if repeatCount <= 0
                return;
            end

            repeatedEntries = repmat({entry}, 1, repeatCount);
            [buffer, count] = MBeautifier.MFormatter.appendOutputEntries(buffer, count, repeatedEntries);
        end

        function [buffer, count] = replaceOutputEntries(buffer, entries)
            count = numel(entries);
            if count == 0
                return;
            end

            if count > numel(buffer)
                buffer{count} = '';
            end

            buffer(1:count) = entries;
        end

        function [parts, count, lastChar] = appendTextPart(parts, count, text)
            count = count + 1;
            parts{count} = text;
            lastChar = text(end);
        end

        function [parts, count] = trimLastOutputChar(parts, count)
            if count == 0
                return;
            end

            lastPart = parts{count};
            if isscalar(lastPart)
                parts{count} = '';
                count = count - 1;
            else
                parts{count} = lastPart(1:end-1);
            end
        end
    end
end
