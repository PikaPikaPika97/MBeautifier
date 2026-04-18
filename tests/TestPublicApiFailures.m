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

        function testFormatCurrentEditorPageErrorsWithoutActiveEditor(testCase)
            testCase.assumeTrue(isempty(matlab.desktop.editor.getActive()), ...
                'This test requires the MATLAB Editor to have no active page.');

            testCase.verifyError(@() MBeautify.formatCurrentEditorPage(), ...
                'MBeautifier:NoActiveEditorPage');
        end

        function testFormatEditorSelectionErrorsWithoutActiveEditor(testCase)
            testCase.assumeTrue(isempty(matlab.desktop.editor.getActive()), ...
                'This test requires the MATLAB Editor to have no active page.');

            testCase.verifyError(@() MBeautify.formatEditorSelection(), ...
                'MBeautifier:NoActiveEditorPage');
        end
    end
end
