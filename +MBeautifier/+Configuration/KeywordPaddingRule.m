classdef KeywordPaddingRule

    properties (SetAccess = immutable)
        Keyword
        RightPadding
    end

    properties (Dependent)
        ReplaceTo
    end

    methods
        function obj = KeywordPaddingRule(keyword, rightPadding)
            obj.Keyword = lower(keyword);
            obj.RightPadding = rightPadding;
        end

        function value = get.ReplaceTo(obj)
            wsPadding = repmat(' ', 1, obj.RightPadding);
            value = [obj.Keyword, wsPadding];
        end
    end

end
