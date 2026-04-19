classdef TestContainerAndContinuationFormatting < matlab.unittest.TestCase
    %TESTCONTAINERANDCONTINUATIONFORMATTING Coverage for container and continuation helpers.

    methods (Test)
        function testContainerScannerReportsNestedDepths(testCase)
            [borders, maxDepth] = MBeautifier.ContainerScanner.calculateDepths('a([1, {b}])');

            testCase.verifyEqual(maxDepth, 4);
            testCase.verifyEqual(cell2mat(borders(:, 1))', [2, 3, 7, 9, 10, 11]);
            testCase.verifyEqual(cell2mat(borders(:, 2))', [1, 2, 3, 3, 2, 1]);
        end

        function testContinuationCommentBuilderPrefixesPlainText(testCase)
            contLineArray = { ...
                'x = [1, ...', 'plain comment'; ...
                '2, ...', '% already comment'; ...
                '3]', ''};

            fullComment = MBeautifier.ContinuationFormatting.buildCommentAsPrecedingLines(contLineArray);

            testCase.verifyEqual(fullComment, sprintf('%% plain comment\n%% already comment'));
        end

        function testContinuationCommentBuilderIgnoresEmptyComments(testCase)
            contLineArray = { ...
                'x = [1, ...', '   '; ...
                '2]', ''};

            fullComment = MBeautifier.ContinuationFormatting.buildCommentAsPrecedingLines(contLineArray);

            testCase.verifyEqual(fullComment, '');
        end

        function testContinuationTokenRecognition(testCase)
            tokenStruct = struct( ...
                'ContinueToken', struct('Token', '#cont#'), ...
                'ContinueMatrixToken', struct('Token', '#matrix#'), ...
                'ContinueCurlyToken', struct('Token', '#curly#'));

            testCase.verifyTrue(MBeautifier.ContinuationFormatting.isContinueToken('#matrix#', tokenStruct));
            testCase.verifyFalse(MBeautifier.ContinuationFormatting.isContinueToken('#other#', tokenStruct));
        end
    end
end
