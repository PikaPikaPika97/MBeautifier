classdef TestShortcutCompatibility < matlab.unittest.TestCase
    %TESTSHORTCUTCOMPATIBILITY Coverage for shortcut support boundaries.

    methods (Test)
        function testCreateShortcutRaisesHelpfulErrorOnUnsupportedReleases(testCase)
            try
                MBeautify.createShortcut('editorpage');
                testCase.assertFail('Expected MBeautify.createShortcut to error.');
            catch ME
                testCase.verifyEqual(ME.identifier, 'MBeautifier:ShortcutNotSupported');
                testCase.verifySubstring(ME.message, 'Create a Favorite manually');
                testCase.verifySubstring(ME.message, 'addpath(');
                testCase.verifySubstring(ME.message, 'MBeautify.formatCurrentEditorPage();');
            end
        end

        function testFileShortcutErrorMessageChecksForCancelBeforeFullfile(testCase)
            try
                MBeautify.createShortcut('file');
                testCase.assertFail('Expected MBeautify.createShortcut to error.');
            catch ME
                testCase.verifyEqual(ME.identifier, 'MBeautifier:ShortcutNotSupported');
                testCase.verifySubstring(ME.message, 'if isequal(sourceFile, 0) || isequal(sourcePath, 0), return; end;');
                testCase.verifySubstring(ME.message, 'if isequal(destFile, 0) || isequal(destPath, 0), return; end;');

                sourceCancelPosition = strfind(ME.message, 'if isequal(sourceFile, 0) || isequal(sourcePath, 0), return; end;');
                sourceFullfilePosition = strfind(ME.message, 'sourceFile = fullfile(sourcePath, sourceFile);');
                destCancelPosition = strfind(ME.message, 'if isequal(destFile, 0) || isequal(destPath, 0), return; end;');
                destFullfilePosition = strfind(ME.message, 'destFile = fullfile(destPath, destFile);');

                testCase.verifyNotEmpty(sourceCancelPosition);
                testCase.verifyNotEmpty(sourceFullfilePosition);
                testCase.verifyLessThan(sourceCancelPosition(1), sourceFullfilePosition(1));
                testCase.verifyNotEmpty(destCancelPosition);
                testCase.verifyNotEmpty(destFullfilePosition);
                testCase.verifyLessThan(destCancelPosition(1), destFullfilePosition(1));
            end
        end
    end
end
