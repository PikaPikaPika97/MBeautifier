classdef LineFormattingStages
    %LINEFORMATTINGSTAGES Focused transformations for one source line.

    methods (Static)
        function actComment = preserveInlineCommentSpacing(actCode, actComment, strategy)
            if isempty(actComment) || ~strcmpi(strategy, 'Preserve')
                return;
            end

            commentSpacing = regexp(actCode, '\s+$', 'match', 'once');
            if ~isempty(commentSpacing)
                actComment = [commentSpacing, actComment];
            end
        end

        function [data, wasHandled] = formatDeclarationLine(data, style)
            style = lower(strtrim(style));
            trimmed = strtrim(data);
            wasHandled = true;

            if isempty(trimmed) || strcmp(style, 'preserve')
                data = trimmed;
                return;
            end

            parts = regexp(trimmed, ...
                '^(?<name>[a-zA-Z]\w*(?:\.[a-zA-Z]\w*)*)(?<shape>\s*\([^=]*?\))?(?<type>(?:\s+[a-zA-Z]\w*(?:\.[a-zA-Z]\w*)*)*)?(?<validators>\s*\{.*\})?(?<default>\s*=\s*.*)?$', ...
                'names', 'once');

            if isempty(parts)
                data = trimmed;
                wasHandled = false;
                return;
            end

            data = MBeautifier.LineFormattingStages.buildDeclaration(parts, style);
        end
    end

    methods (Static, Access = private)
        function data = buildDeclaration(parts, style)
            shape = strtrim(parts.shape);
            type = strtrim(parts.type);
            validators = strtrim(parts.validators);
            defaultValue = strtrim(parts.default);

            data = parts.name;
            if strcmp(style, 'compact')
                data = MBeautifier.LineFormattingStages.appendCompactDeclarationParts( ...
                    data, shape, type, validators);
            else
                data = MBeautifier.LineFormattingStages.appendReadableDeclarationParts( ...
                    data, shape, type, validators);
            end

            if ~isempty(defaultValue)
                defaultValue = regexprep(defaultValue, '^\s*=\s*', '');
                data = [data, ' = ', strtrim(defaultValue)];
            end
        end

        function data = appendCompactDeclarationParts(data, shape, type, validators)
            if ~isempty(shape)
                data = [data, shape];
            end
            if ~isempty(type)
                data = [data, ' ', type];
            end
            if ~isempty(validators)
                data = [data, validators];
            end
        end

        function data = appendReadableDeclarationParts(data, shape, type, validators)
            if ~isempty(shape)
                data = [data, ' ', shape];
            end
            if ~isempty(type)
                data = [data, ' ', type];
            end
            if ~isempty(validators)
                data = [data, ' ', validators];
            end
        end
    end
end
