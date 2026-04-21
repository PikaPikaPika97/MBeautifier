classdef ContainerScanner
    %CONTAINERSCANNER Locate bracket container boundaries in tokenized code.

    methods (Static)
        function [containerBorderIndexes, maxDepth] = calculateDepths(data)
            containerBorderIndexes = cell(numel(data), 2);
            borderCount = 0;
            depth = 1;
            maxDepth = 1;

            for index = 1:numel(data)
                borderFound = true;
                if any(strcmp(data(index), MBeautifier.Constants.ContainerOpeningBrackets))
                    newDepth = depth + 1;
                    maxDepth = max(maxDepth, newDepth);
                elseif any(strcmp(data(index), MBeautifier.Constants.ContainerClosingBrackets))
                    newDepth = depth - 1;
                    depth = depth - 1;
                else
                    borderFound = false;
                end

                if borderFound
                    borderCount = borderCount + 1;
                    containerBorderIndexes{borderCount, 1} = index;
                    containerBorderIndexes{borderCount, 2} = depth;
                    depth = newDepth;
                end
            end

            containerBorderIndexes = containerBorderIndexes(1:borderCount, :);
        end
    end
end
