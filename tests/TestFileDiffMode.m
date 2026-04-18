classdef TestFileDiffMode < matlab.unittest.TestCase
    %TESTFILEDIFFMODE Coverage for single-file inspection APIs.

    methods (Test)
        function testCheckFileReportsUnchangedForGoldenFixture(testCase)
            fixture = FormatterTestUtils.copyFixtureToTemp('testfile.m');

            result = MBeautify.checkFile(fixture);

            testCase.verifyFalse(result.changed);
            testCase.verifyEqual(result.status, 'unchanged');
            testCase.verifyEqual(result.diffSummary.lineChanges, 0);
        end

        function testDiffFileReturnsSummaryForUnformattedFile(testCase)
            file = FormatterTestUtils.writeTempTextFile('testDiffFile.m', ...
                sprintf('function y=foo(x)\ny=x+1;\nend\n'));

            result = MBeautify.diffFile(file);

            testCase.verifyTrue(result.changed);
            testCase.verifyEqual(result.status, 'changed');
            testCase.verifyGreaterThan(result.diffSummary.lineChanges, 0);
            testCase.verifyNotEmpty(result.diffSummary.preview);
        end

        function testCheckFileSupportsExplicitEditorInspection(testCase)
            file = FormatterTestUtils.writeTempTextFile('testCheckFileEditor.m', ...
                sprintf('function y=foo(x)\ny=x+1;\nend\n'));

            result = MBeautify.checkFile(file, 'Editor', true);

            testCase.verifyTrue(result.changed);
            testCase.verifyGreaterThan(result.diffSummary.firstChangeLine, 0);
        end
    end
end
