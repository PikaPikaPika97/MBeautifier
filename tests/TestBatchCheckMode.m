classdef TestBatchCheckMode < matlab.unittest.TestCase
    %TESTBATCHCHECKMODE Coverage for non-mutating batch inspection APIs.

    methods (Test)
        function testCheckFilesReportsChangedAndUnchangedWithoutWriting(testCase)
            directory = FormatterTestUtils.createTempDirectory();
            testCase.addTeardown(@() rmdir(directory, 's'));

            changedFile = fullfile(directory, 'needsFormatting.m');
            unchangedFile = fullfile(directory, 'alreadyFormatted.m');
            changedText = sprintf('function y=foo(x)\ny=x+1;\nend\n');
            unchangedText = FormatterTestUtils.formatText(changedText);

            FormatterTestUtils.writeTextFileForTest(changedFile, changedText);
            FormatterTestUtils.writeTextFileForTest(unchangedFile, unchangedText);

            result = MBeautify.checkFiles(directory, '*.m', false, false);

            testCase.verifyEqual(result.filesScanned, 2);
            testCase.verifyEqual(result.filesChanged, 1);
            testCase.verifyEqual(result.filesUnchanged, 1);
            testCase.verifyEqual(result.filesFailed, 0);
            testCase.verifyEqual( ...
                FormatterTestUtils.normalizeText(FormatterTestUtils.readText(changedFile)), ...
                FormatterTestUtils.normalizeText(changedText));
            testCase.verifyEqual( ...
                FormatterTestUtils.normalizeText(FormatterTestUtils.readText(unchangedFile)), ...
                FormatterTestUtils.normalizeText(unchangedText));

            changedDetail = TestBatchCheckMode.detailForPath(result, changedFile);
            unchangedDetail = TestBatchCheckMode.detailForPath(result, unchangedFile);
            testCase.verifyTrue(changedDetail.changed);
            testCase.verifyFalse(unchangedDetail.changed);
            testCase.verifyGreaterThan(changedDetail.diffSummary.lineChanges, 0);
            testCase.verifyEqual(unchangedDetail.diffSummary.lineChanges, 0);
        end

        function testDiffFilesReturnsPreviewWithoutWriting(testCase)
            directory = FormatterTestUtils.createTempDirectory();
            testCase.addTeardown(@() rmdir(directory, 's'));

            file = fullfile(directory, 'needsDiff.m');
            input = sprintf('function y=foo(x)\ny=x+1;\nend\n');
            FormatterTestUtils.writeTextFileForTest(file, input);

            result = MBeautify.diffFiles(directory, '*.m', false, false);
            detail = TestBatchCheckMode.detailForPath(result, file);

            testCase.verifyTrue(detail.changed);
            testCase.verifyGreaterThan(detail.diffSummary.lineChanges, 0);
            testCase.verifyNotEmpty(detail.diffSummary.preview);
            testCase.verifyEqual( ...
                FormatterTestUtils.normalizeText(FormatterTestUtils.readText(file)), ...
                FormatterTestUtils.normalizeText(input));
        end

        function testCheckFilesSupportsEditorModeWithoutWriting(testCase)
            directory = FormatterTestUtils.createTempDirectory();
            testCase.addTeardown(@() rmdir(directory, 's'));

            file = fullfile(directory, 'editorPreview.m');
            input = sprintf('function y=foo(x)\ny=x+1;\nend\n');
            FormatterTestUtils.writeTextFileForTest(file, input);

            result = MBeautify.checkFiles(directory, 'Editor', true);
            detail = TestBatchCheckMode.detailForPath(result, file);

            testCase.verifyTrue(detail.changed);
            testCase.verifyEqual( ...
                FormatterTestUtils.normalizeText(FormatterTestUtils.readText(file)), ...
                FormatterTestUtils.normalizeText(input));
        end
    end

    methods (Static, Access = private)
        function detail = detailForPath(result, path)
            details = result.details;
            matches = strcmp({details.path}, path);
            detail = details(find(matches, 1, 'first'));
        end
    end
end
