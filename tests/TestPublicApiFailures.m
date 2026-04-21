classdef TestPublicApiFailures < matlab.unittest.TestCase
    %TESTPUBLICAPIFAILURES Coverage for explicit public API failures.

    methods (Test)
        function testFormatFileNoEditorErrorsForMissingFile(testCase)
            missingFile = fullfile(tempdir, 'mbeautifier_missing_file_no_editor.m');
            if exist(missingFile, 'file') == 2
                delete(missingFile);
            end

            testCase.verifyError(@() MBeautify.formatFileNoEditor(missingFile), ...
                'MBeautifier:FileDoesNotExist');
        end

        function testFormatFileErrorsForMissingFile(testCase)
            missingFile = fullfile(tempdir, 'mbeautifier_missing_file_editor.m');
            if exist(missingFile, 'file') == 2
                delete(missingFile);
            end

            testCase.verifyError(@() MBeautify.formatFile(missingFile), ...
                'MBeautifier:FileDoesNotExist');
        end

        function testCheckFileErrorsForMissingFile(testCase)
            missingFile = fullfile(tempdir, 'mbeautifier_missing_file_check.m');
            if exist(missingFile, 'file') == 2
                delete(missingFile);
            end

            testCase.verifyError(@() MBeautify.checkFile(missingFile), ...
                'MBeautifier:FileDoesNotExist');
        end

        function testDiffFileErrorsForMissingFile(testCase)
            missingFile = fullfile(tempdir, 'mbeautifier_missing_file_diff.m');
            if exist(missingFile, 'file') == 2
                delete(missingFile);
            end

            testCase.verifyError(@() MBeautify.diffFile(missingFile), ...
                'MBeautifier:FileDoesNotExist');
        end

        function testInvalidIndentationCharacterErrors(testCase)
            configuration = FormatterTestUtils.loadConfiguration( ...
                struct('IndentationCharacter', 'invalid'));

            testCase.verifyError( ...
                @() MBeautifier.FormattingPipeline.formatText(sprintf('x=1;\n'), configuration), ...
                'MBeautifier:Configuration:InvalidIndentationCharacter');
        end

        function testFormatCurrentEditorPageErrorsWithoutActiveEditor(testCase)
            EditorTestUtils.closeAllDocuments();

            testCase.verifyError(@() MBeautify.formatCurrentEditorPage(), ...
                'MBeautifier:NoActiveEditorPage');
        end

        function testFormatEditorSelectionErrorsWithoutActiveEditor(testCase)
            EditorTestUtils.closeAllDocuments();

            testCase.verifyError(@() MBeautify.formatEditorSelection(), ...
                'MBeautifier:NoActiveEditorPage');
        end
    end
end
