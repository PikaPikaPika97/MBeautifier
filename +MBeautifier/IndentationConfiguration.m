classdef IndentationConfiguration
    %INDENTATIONCONFIGURATION Validate and build indentation settings.

    methods (Static)
        function indent = indentationString(indentationCharacter, indentationCount)
            if strcmpi(indentationCharacter, 'white-space')
                indent = repmat(' ', 1, indentationCount);
            elseif strcmpi(indentationCharacter, 'tab')
                indent = '\t';
            else
                error('MBeautifier:Configuration:InvalidIndentationCharacter', ...
                    ['The IndentationCharacter configuration value must be ', ...
                    '"white-space" or "tab".']);
            end
        end
    end
end
