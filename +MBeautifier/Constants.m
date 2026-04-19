classdef Constants
    properties (Constant)
        WhiteSpaceToken = '#MBeauty_WhiteSpace_Token#';
        StringToken = '#MBeutyString#';

        ContainerOpeningBrackets = {'[', '{', '('};
        ContainerClosingBrackets = {']', '}', ')'};
        NewLine = newline;
    end

    methods (Access = private)
        function obj = Constants()
        end
    end
end
