classdef ContinuationFormatting
    %CONTINUATIONFORMATTING Helpers for continued source lines.

    methods (Static)
        function tf = isContinueToken(element, tokenStruct)
            tf = strcmp(element, tokenStruct.ContinueToken.Token) || ...
                strcmp(element, tokenStruct.ContinueMatrixToken.Token) || ...
                strcmp(element, tokenStruct.ContinueCurlyToken.Token);
        end

        function fullComment = buildCommentAsPrecedingLines(contLineArray)
            comments = cell(1, max(0, size(contLineArray, 1) - 1));
            commentCount = 0;

            for index = 1:size(contLineArray, 1) - 1
                currentComment = contLineArray{index, 2};
                if isempty(strtrim(currentComment))
                    continue;
                end

                commentToAdd = currentComment;
                if isempty(regexp(currentComment, '^\s*%', 'once'))
                    commentToAdd = ['% ', currentComment];
                end

                commentCount = commentCount + 1;
                comments{commentCount} = commentToAdd;
            end

            if commentCount == 0
                fullComment = '';
            else
                fullComment = strjoin(comments(1:commentCount), MBeautifier.Constants.NewLine);
            end
        end
    end
end
