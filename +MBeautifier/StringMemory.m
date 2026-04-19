classdef StringMemory < handle

    properties (SetAccess = immutable)
        Mementos;
        OriginalCodeLine;
        MemorizedCodeLine;
    end

    methods (Access = private)
        function obj = StringMemory(originalCodeLine, replacedCodeLine, mementos)
            obj.Mementos = mementos;
            obj.OriginalCodeLine = originalCodeLine;
            obj.MemorizedCodeLine = replacedCodeLine;
        end
    end

    methods (Static)
        function stringMemory = fromCodeLine(actCode)
            % Possible formats:
            % 'text'
            % ' text '' " text2 '
            % " text "
            % " text "" ' text2"

            indices = regexp(actCode, '''|"');
            mementos = cell(1, max(1, floor(numel(indices) / 2)));
            mementoCount = 0;
            strArray = cell(1, numel(indices)+1);

            if numel(indices) > 1
                stringStartedWith = '';
                currentStringParts = cell(1, numel(indices));
                currentStringPartCount = 0;
                isInString = false;
                lastWasEscape = false;
                for iMatch = 1:numel(indices)
                    if ~isInString
                        if iMatch == 1
                            predecingPart = actCode(1:indices(iMatch)-1);
                        else
                            predecingPart = actCode(indices(iMatch-1)+1:indices(iMatch)-1);
                        end
                        strArray{iMatch} = predecingPart;
                        isInString = true;
                        stringStartedWith = actCode(indices(iMatch));
                        continue
                    end

                    if lastWasEscape
                        currentStringPartCount = currentStringPartCount + 1;
                        currentStringParts{currentStringPartCount} = actCode(indices(iMatch));
                        lastWasEscape = false;
                        continue
                    end

                    % String started with " and the current character is ' (or vice-versa) -> it is still part of the
                    % string
                    if ~strcmp(stringStartedWith, actCode(indices(iMatch)))
                        currentStringPartCount = currentStringPartCount + 1;
                        currentStringParts{currentStringPartCount} = actCode(indices(iMatch-1)+1:indices(iMatch));
                    else
                        % String started with ' and the same character comes (or " case)

                        isEndOfString = numel(indices) == iMatch || indices(iMatch) + 1 ~= indices(iMatch+1);

                        if isEndOfString
                            currentStringPartCount = currentStringPartCount + 1;
                            currentStringParts{currentStringPartCount} = actCode(indices(iMatch-1)+1:indices(iMatch)-1);
                            currentString = [currentStringParts{1:currentStringPartCount}];


                            if strcmp(stringStartedWith, '''')
                                memento = MBeautifier.CharacterArrayStringMemento(currentString);
                            elseif strcmp(stringStartedWith, '"')
                                memento = MBeautifier.StringArrayStringMemento(currentString);
                            else
                                error('MBeautifier:InternalError', 'Unknown problem happened while processing strings.')
                            end
                            mementoCount = mementoCount + 1;
                            mementos{mementoCount} = memento;

                            strArray{iMatch} = MBeautifier.Constants.StringToken;
                            isInString = false;
                            currentStringPartCount = 0;
                        else
                            currentStringPartCount = currentStringPartCount + 1;
                            currentStringParts{currentStringPartCount} = actCode(indices(iMatch-1)+1:indices(iMatch));
                            lastWasEscape = true;
                        end
                    end
                end

                % Append the trailing part if any
                if indices(end) < numel(actCode)
                    strArray{end} = actCode(indices(end)+1:end);
                end

                actCodeTemp = [strArray{:}];
            else
                actCodeTemp = actCode;
            end

            mementos = mementos(1:mementoCount);
            stringMemory = MBeautifier.StringMemory(actCode, actCodeTemp, mementos);
        end
    end

end
