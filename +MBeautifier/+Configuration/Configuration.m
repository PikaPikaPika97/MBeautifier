classdef Configuration < handle

    properties (Access = private)
        OperatorPaddingRules;
        OperatorPaddingRuleNamesInOrder;
        KeywordPaddingRules;
        SpecialRules;
    end

    methods (Access = private)
        function obj = Configuration(operatorPaddingRules, operatorPaddingRuleNamesInOrder, keywordRules, specialRules)
            obj.OperatorPaddingRules = operatorPaddingRules;
            obj.SpecialRules = specialRules;
            obj.KeywordPaddingRules = keywordRules;
            obj.OperatorPaddingRuleNamesInOrder = operatorPaddingRuleNamesInOrder;
        end
    end

    methods

        function rule = specialRule(obj, name)
            rule = obj.SpecialRules(lower(name));
        end

        function tf = hasSpecialRule(obj, name)
            tf = obj.SpecialRules.isKey(lower(name));
        end

        function rules = specialRules(obj)
            rules = obj.SpecialRules.values;
        end

        function rule = operatorPaddingRule(obj, name)
            rule = obj.OperatorPaddingRules(lower(name));
        end

        function rule = keywordPaddingRule(obj, name)
            rule = obj.KeywordPaddingRules(lower(name));
        end

        function rules = keywordPaddingRules(obj)
            rules = obj.KeywordPaddingRules.values;
        end

        function names = operatorPaddingRuleNames(obj)
            keys = obj.OperatorPaddingRuleNamesInOrder;
            names = cell(1, numel(keys));
            for i = 1:numel(keys)
                names{i} = obj.operatorPaddingRule(keys{i}).Key;
            end
        end

        function characters = operatorCharacters(obj)
            keys = obj.OperatorPaddingRules.keys();
            characters = cell(1, numel(keys));
            for i = 1:numel(keys)
                characters{i} = obj.operatorPaddingRule(keys{i}).ValueFrom;
            end
        end

        function value = statementBreakStrategy(obj)
            value = obj.specialRuleValueOr('StatementBreakStrategy', obj.legacyStatementBreakStrategy());
        end

        function value = declarationSpacingStyle(obj)
            value = obj.specialRuleValueOr('DeclarationSpacingStyle', 'Readable');
        end

        function value = inlineCommentSpacingStrategy(obj)
            value = obj.specialRuleValueOr('InlineCommentSpacingStrategy', obj.legacyInlineCommentSpacingStrategy());
        end

        function value = maximalNewLines(obj)
            value = obj.specialRuleDoubleValueOr('MaximalNewLines', 2);
        end

        function value = sectionPrecedingNewlineCount(obj)
            value = obj.specialRuleDoubleValueOr('SectionPrecedingNewlineCount', -1);
        end

        function value = sectionTrailingNewlineCount(obj)
            value = obj.specialRuleDoubleValueOr('SectionTrailingNewlineCount', -1);
        end

        function value = startingNewlineCount(obj)
            value = obj.specialRuleDoubleValueOr('StartingNewlineCount', 0);
        end

        function value = endingNewlineCount(obj)
            value = obj.specialRuleDoubleValueOr('EndingNewlineCount', 1);
        end

        function tf = inlineContinuousLines(obj)
            tf = obj.specialRuleDoubleValueOr('InlineContinousLines', 0) ~= 0;
        end

        function tf = inlineContinuousLinesInMatrixes(obj)
            tf = obj.specialRuleDoubleValueOr('InlineContinousLinesInMatrixes', 0) ~= 0;
        end

        function tf = inlineContinuousLinesInCurlyBracket(obj)
            tf = obj.specialRuleDoubleValueOr('InlineContinousLinesInCurlyBracket', 0) ~= 0;
        end

        function tf = hasInlineContinuousLineRule(obj)
            tf = obj.inlineContinuousLines() ...
                || obj.inlineContinuousLinesInMatrixes() ...
                || obj.inlineContinuousLinesInCurlyBracket();
        end

        function tf = autoAppendContinuationMarkers(obj)
            tf = obj.specialRuleDoubleValueOr('AutoAppendContinuationMarkers', 0) ~= 0;
        end

        function tf = preserveIndexExpressionSpacing(obj)
            tf = obj.specialRuleDoubleValueOr('PreserveIndexExpressionSpacing', 1) ~= 0;
        end

        function tf = addCommasToMatrices(obj)
            tf = obj.specialRuleDoubleValueOr('AddCommasToMatrices', 1) ~= 0;
        end

        function tf = addCommasToCellArrays(obj)
            tf = obj.specialRuleDoubleValueOr('AddCommasToCellArrays', 1) ~= 0;
        end

        function tf = matrixIndexingOperatorPadding(obj)
            tf = obj.specialRuleDoubleValueOr('MatrixIndexing_ArithmeticOperatorPadding', 0) ~= 0;
        end

        function tf = cellArrayIndexingOperatorPadding(obj)
            tf = obj.specialRuleDoubleValueOr('CellArrayIndexing_ArithmeticOperatorPadding', 0) ~= 0;
        end

        function value = indentationStrategy(obj)
            value = obj.specialRuleValueOr('Indentation_Strategy', 'NestedFunctions');
        end

        function tf = trimBlankLinesDuringIndentation(obj)
            tf = obj.specialRuleDoubleValueOr('Indentation_TrimBlankLines', 1) ~= 0;
        end

        function indent = indentationString(obj)
            indentationCharacter = obj.specialRuleValueOr('IndentationCharacter', 'white-space');
            indentationCount = obj.specialRuleDoubleValueOr('IndentationCount', 4);
            indent = MBeautifier.IndentationConfiguration.indentationString( ...
                indentationCharacter, indentationCount);
        end

        function tf = indentScriptLocalFunctionBodies(obj)
            tf = obj.specialRuleDoubleValueOr('IndentScriptLocalFunctionBodies', 1) ~= 0;
        end
    end

    methods (Static)
        function obj = fromFile(xmlFile)
            obj = MBeautifier.Configuration.Configuration.readSettingsXML(xmlFile);
        end
    end

    methods (Access = private)
        function value = specialRuleValueOr(obj, name, defaultValue)
            if obj.hasSpecialRule(name)
                value = strtrim(obj.specialRule(name).Value);
            else
                value = defaultValue;
            end
        end

        function value = specialRuleDoubleValueOr(obj, name, defaultValue)
            if obj.hasSpecialRule(name)
                value = obj.specialRule(name).ValueAsDouble;
            else
                value = defaultValue;
            end
        end

        function value = legacyStatementBreakStrategy(obj)
            if obj.hasSpecialRule('AllowMultipleStatementsPerLine') && ...
                    obj.specialRule('AllowMultipleStatementsPerLine').ValueAsDouble ~= 0
                value = 'Never';
            else
                value = 'Always';
            end
        end

        function value = legacyInlineCommentSpacingStrategy(obj)
            if obj.hasSpecialRule('PreserveInlineCommentSpacing') && ...
                    obj.specialRule('PreserveInlineCommentSpacing').ValueAsDouble ~= 0
                value = 'Preserve';
            else
                value = 'Normalize';
            end
        end
    end

    methods (Static, Access = private)
        function configuration = readSettingsXML(xmlFile)
            XMLDoc = xmlread(xmlFile);

            allOperatorItems = XMLDoc.getElementsByTagName('OperatorPaddingRule');
            operatorRules = containers.Map();
            operatorCount = allOperatorItems.getLength();
            operatorPaddingRuleNamesInOrder = cell(1, operatorCount);

            for iOperator = 0:operatorCount - 1
                currentOperator = allOperatorItems.item(iOperator);
                key = char(currentOperator.getElementsByTagName('Key').item(0).getTextContent().toString());
                from = removeXMLEscaping(char(currentOperator.getElementsByTagName('ValueFrom').item(0).getTextContent().toString()));
                to = removeXMLEscaping(char(currentOperator.getElementsByTagName('ValueTo').item(0).getTextContent().toString()));

                operatorPaddingRuleNamesInOrder{iOperator+1} = lower(key);
                operatorRules(lower(key)) = MBeautifier.Configuration.OperatorPaddingRule(key, from, to);
            end

            allSpecialItems = XMLDoc.getElementsByTagName('SpecialRule');
            specialRules = containers.Map();

            for iSpecRule = 0:allSpecialItems.getLength() - 1
                currentRule = allSpecialItems.item(iSpecRule);
                key = char(currentRule.getElementsByTagName('Key').item(0).getTextContent().toString());
                value = char(currentRule.getElementsByTagName('Value').item(0).getTextContent().toString());

                specialRules(lower(key)) = MBeautifier.Configuration.SpecialRule(key, value);
            end

            allKeywordItems = XMLDoc.getElementsByTagName('KeyworPaddingRule');
            keywordRules = containers.Map();

            for iKeywordRule = 0:allKeywordItems.getLength() - 1
                currentRule = allKeywordItems.item(iKeywordRule);
                keyword = char(currentRule.getElementsByTagName('Keyword').item(0).getTextContent().toString());
                rightPadding = str2double(char(currentRule.getElementsByTagName('RightPadding').item(0).getTextContent().toString()));

                keywordRules(lower(keyword)) = MBeautifier.Configuration.KeywordPaddingRule(keyword, rightPadding);
            end

            configuration = MBeautifier.Configuration.Configuration(operatorRules, operatorPaddingRuleNamesInOrder, keywordRules, specialRules);

            function escapedValue = removeXMLEscaping(value)
                escapedValue = regexprep(value, '&lt;', '<');
                escapedValue = regexprep(escapedValue, '&amp;', '&');
                escapedValue = regexprep(escapedValue, '&gt;', '>');
            end
        end
    end
end
