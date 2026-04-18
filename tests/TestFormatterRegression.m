classdef TestFormatterRegression < matlab.unittest.TestCase
    %TESTFORMATTERREGRESSION Regression coverage for the headless formatter pipeline.

    methods (Test)
        function testGoldenRegressionOnTestfile(testCase)
            input = FormatterTestUtils.readFixture('testfile.m');
            formatted = FormatterTestUtils.formatText(input);

            testCase.verifyEqual( ...
                FormatterTestUtils.normalizeText(formatted), ...
                FormatterTestUtils.normalizeText(input));
        end

        function testFormattingIsIdempotent(testCase)
            input = FormatterTestUtils.readFixture('testfile.m');
            onceFormatted = FormatterTestUtils.formatText(input);
            twiceFormatted = FormatterTestUtils.formatText(onceFormatted);

            testCase.verifyEqual( ...
                FormatterTestUtils.normalizeText(twiceFormatted), ...
                FormatterTestUtils.normalizeText(onceFormatted));
        end

        function testFormatFileNoEditorWritesExpectedOutput(testCase)
            inputCopy = FormatterTestUtils.copyFixtureToTemp('testfile.m');
            outputPath = fullfile(fileparts(inputCopy), 'formatted_testfile.m');

            MBeautify.formatFileNoEditor(inputCopy, outputPath);

            actual = FormatterTestUtils.readText(outputPath);
            expected = FormatterTestUtils.readFixture('testfile.m');

            testCase.verifyEqual( ...
                FormatterTestUtils.normalizeText(actual), ...
                FormatterTestUtils.normalizeText(expected));
        end

        function testKnownBugFixtureIsFormattedLikeTheGoldenOutput(testCase)
            bugFixturePath = FormatterTestUtils.fixturePath('testfile_bugs.m');
            testCase.verifyTrue(exist(bugFixturePath, 'file') == 2);

            input = FormatterTestUtils.readText(bugFixturePath);
            formatted = FormatterTestUtils.formatText(input);

            testCase.verifyEqual( ...
                FormatterTestUtils.normalizeText(formatted), ...
                FormatterTestUtils.normalizeText(input), ...
                ['Issue #35 must keep arithmetic spacing in function calls even when ', ...
                'matrix indexing arithmetic padding is disabled.']);
        end
    end
end
