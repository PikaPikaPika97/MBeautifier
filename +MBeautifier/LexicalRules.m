classdef LexicalRules
    %LEXICALRULES Shared lexical predicates for MATLAB source scanning.

    methods (Static)
        function tf = isTransposeQuote(previousNonspace)
            tf = ~isempty(previousNonspace) && ...
                ~isempty(regexp(previousNonspace, '[a-zA-Z0-9_\)\]\}\."]', 'once'));
        end
    end
end
