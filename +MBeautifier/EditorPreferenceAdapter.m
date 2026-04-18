classdef EditorPreferenceAdapter
    %EDITORPREFERENCEADAPTER Wrap MATLAB Editor indentation preference access.

    methods (Static)
        function preference = getIndentPreference()
            preference = char(com.mathworks.services.Prefs.getStringPref('EditorMFunctionIndentType'));
        end

        function setIndentPreference(preference)
            com.mathworks.services.Prefs.setStringPref('EditorMFunctionIndentType', preference);
        end

        function restoreIndentPreference(preference)
            currentPreference = MBeautifier.EditorPreferenceAdapter.getIndentPreference();
            if ~strcmp(currentPreference, preference)
                MBeautifier.EditorPreferenceAdapter.setIndentPreference(preference);
            end
        end
    end
end
