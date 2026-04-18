classdef TestShortcutCompatibility < matlab.unittest.TestCase
    %TESTSHORTCUTCOMPATIBILITY Coverage for shortcut support boundaries.

    methods (Test)
        function testCreateShortcutRaisesHelpfulErrorOnUnsupportedReleases(testCase)
            if exist('isMATLABReleaseOlderThan', 'file') == 2
                isOlderThanR2025a = isMATLABReleaseOlderThan('R2025a');
            else
                isOlderThanR2025a = verLessThan('matlab', '25.1');
            end

            testCase.assumeFalse(isOlderThanR2025a, ...
                'This test requires MATLAB R2025a or newer.');

            try
                MBeautify.createShortcut('editorpage');
                testCase.assertFail('Expected MBeautify.createShortcut to error on MATLAB R2025a+.');
            catch ME
                testCase.verifyEqual(ME.identifier, 'MBeautifier:ShortcutNotSupported');
                testCase.verifySubstring(ME.message, 'Create a Favorite manually');
                testCase.verifySubstring(ME.message, 'addpath(');
                testCase.verifySubstring(ME.message, 'MBeautify.formatCurrentEditorPage();');
            end
        end
    end
end
