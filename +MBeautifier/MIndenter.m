classdef MIndenter < handle
    %MINDENTER Facade for source indentation.

    properties (Access = private)
        Engine;
    end

    methods
        function obj = MIndenter(configuration)
            obj.Engine = MBeautifier.BlockIndentationEngine(configuration);
        end

        function indentedSource = performIndenting(obj, source)
            indentedSource = obj.Engine.performIndenting(source);
        end
    end
end
