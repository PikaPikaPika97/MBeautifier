classdef TestBlockIndentationEngine < matlab.unittest.TestCase
    %TESTBLOCKINDENTATIONENGINE Coverage for the extracted indentation engine.

    methods (Test)
        function testEngineIndentsIfElseBlock(testCase)
            configuration = FormatterTestUtils.loadConfiguration();
            engine = MBeautifier.BlockIndentationEngine(configuration);
            input = sprintf('if flag\ny = 1;\nelse\ny = 2;\nend\n');
            expected = sprintf('if flag\n    y = 1;\nelse\n    y = 2;\nend\n');

            indented = engine.performIndenting(input);

            testCase.verifyEqual( ...
                FormatterTestUtils.normalizeText(indented), ...
                FormatterTestUtils.normalizeText(expected));
        end

        function testEngineIndentsContinuationLine(testCase)
            configuration = FormatterTestUtils.loadConfiguration();
            engine = MBeautifier.BlockIndentationEngine(configuration);
            input = sprintf('x = firstPart + ...\nsecondPart;\n');
            expected = sprintf('x = firstPart + ...\n    secondPart;\n');

            indented = engine.performIndenting(input);

            testCase.verifyEqual( ...
                FormatterTestUtils.normalizeText(indented), ...
                FormatterTestUtils.normalizeText(expected));
        end
    end
end
