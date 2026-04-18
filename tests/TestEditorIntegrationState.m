classdef TestEditorIntegrationState < matlab.unittest.TestCase
    %TESTEDITORINTEGRATIONSTATE Coverage for editor integration state handling.

    methods (Test)
        function testTemporaryEditorIndentPreferenceIsRestoredAfterError(testCase)
            configuration = FormatterTestUtils.loadConfiguration( ...
                struct('Indentation_Strategy', 'nestedfunctions'));
            originalPreference = MBeautifier.EditorApp.getEditorIndentPreference();
            testPreference = 'ClassicFunctionIndent';

            MBeautifier.EditorApp.setEditorIndentPreference(testPreference);
            cleanup = onCleanup(@() MBeautifier.EditorApp.setEditorIndentPreference(originalPreference)); %#ok<NASGU>

            testCase.verifyError( ...
                @() MBeautifier.EditorApp.runWithTemporaryEditorIndentPreference(configuration, ...
                @() error('MBeautifier:Test:ForcedFailure', 'Forced failure for cleanup verification.')), ...
                'MBeautifier:Test:ForcedFailure');

            testCase.verifyEqual(MBeautifier.EditorApp.getEditorIndentPreference(), testPreference);
        end
    end
end
