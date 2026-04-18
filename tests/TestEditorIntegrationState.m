classdef TestEditorIntegrationState < matlab.unittest.TestCase
    %TESTEDITORINTEGRATIONSTATE Coverage for editor integration state handling.

    methods (Test)
        function testTemporaryEditorIndentPreferenceIsRestoredAfterError(testCase)
            configuration = FormatterTestUtils.loadConfiguration( ...
                struct('Indentation_Strategy', 'nestedfunctions'));
            originalPreference = MBeautify.getEditorIndentPreference();
            testPreference = 'ClassicFunctionIndent';

            MBeautify.setEditorIndentPreference(testPreference);
            cleanup = onCleanup(@() MBeautify.setEditorIndentPreference(originalPreference));

            testCase.verifyError( ...
                @() MBeautify.runWithTemporaryEditorIndentPreference(configuration, ...
                @() error('MBeautifier:Test:ForcedFailure', 'Forced failure for cleanup verification.')), ...
                'MBeautifier:Test:ForcedFailure');

            testCase.verifyEqual(MBeautify.getEditorIndentPreference(), testPreference);
        end
    end
end
