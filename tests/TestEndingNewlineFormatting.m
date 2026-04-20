classdef TestEndingNewlineFormatting < matlab.unittest.TestCase
    %TESTENDINGNEWLINEFORMATTING Coverage for EndingNewlineCount behavior.

    methods (Test)
        function testEndingNewlineCountZeroRemovesTrailingNewlines(testCase)
            input = sprintf('x=1;\n\n');
            expected = 'x = 1;';

            formatted = FormatterTestUtils.formatText(input, ...
                struct('EndingNewlineCount', '0'));

            testCase.verifyEqual(formatted, expected);
        end

        function testEndingNewlineCountOneLeavesSingleTrailingNewline(testCase)
            input = sprintf('x=1;\n\n');
            expected = sprintf('x = 1;\n');

            formatted = FormatterTestUtils.formatText(input, ...
                struct('EndingNewlineCount', '1'));

            testCase.verifyEqual(formatted, expected);
        end

        function testNegativeEndingNewlineCountPreservesTrailingNewlines(testCase)
            input = sprintf('x=1;\n\n');
            expected = sprintf('x = 1;\n\n');

            formatted = FormatterTestUtils.formatText(input, ...
                struct('EndingNewlineCount', '-1'));

            testCase.verifyEqual(formatted, expected);
        end
    end
end
