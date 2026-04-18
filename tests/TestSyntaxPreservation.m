classdef TestSyntaxPreservation < matlab.unittest.TestCase
    %TESTSYNTAXPRESERVATION Ensure formatting does not introduce syntax errors.

    methods (Test)
        function testGoldenFixtureRemainsSyntaxClean(testCase)
            formatted = FormatterTestUtils.formatText(FormatterTestUtils.readFixture('testfile.m'));
            TestSyntaxPreservation.verifyNoSyntaxIssues(testCase, formatted, 'testfile_syntax_fixture.m');
        end

        function testIssue0035FixtureRemainsSyntaxClean(testCase)
            formatted = FormatterTestUtils.formatText(FormatterTestUtils.readFixture(fullfile('issues', ...
                'issue_0035_function_call_arithmetic_spacing.m')));
            TestSyntaxPreservation.verifyNoSyntaxIssues(testCase, formatted, 'issue_0035_function_call_arithmetic_spacing.m');
        end

        function testArgumentsBlockExampleRemainsSyntaxClean(testCase)
            input = sprintf([ ...
                'function y = foo(x, options)\n', ...
                'arguments\n', ...
                '    x(1,1) double{mustBeFinite,mustBeReal}=""\n', ...
                '    options.name(1,1) string{mustBeNonzeroLengthText}="demo"\n', ...
                'end\n', ...
                'y = x;\n', ...
                'end\n']);

            formatted = FormatterTestUtils.formatText(input, ...
                struct('DeclarationSpacingStyle', 'Readable'));
            TestSyntaxPreservation.verifyNoSyntaxIssues(testCase, formatted, 'foo.m');
        end
    end

    methods (Static, Access = private)
        function verifyNoSyntaxIssues(testCase, text, fileName)
            path = FormatterTestUtils.writeTempTextFile(fileName, text);
            ids = FormatterTestUtils.checkcodeIds(path);
            syntaxIssueIds = {'SYNER', 'ENDCT', 'ENDCT1', 'ENDCT2', 'NOPAR'};
            hasSyntaxIssue = ismember(ids, syntaxIssueIds);

            testCase.verifyFalse(any(hasSyntaxIssue), ...
                sprintf('Unexpected syntax issues detected: %s', strjoin(ids(hasSyntaxIssue), ', ')));
        end
    end
end
