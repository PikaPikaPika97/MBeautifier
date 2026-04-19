classdef TestLineFormattingStages < matlab.unittest.TestCase
    %TESTLINEFORMATTINGSTAGES Coverage for focused single-line stages.

    methods (Test)
        function testPreserveInlineCommentSpacingKeepsTrailingCodeSpaces(testCase)
            comment = MBeautifier.LineFormattingStages.preserveInlineCommentSpacing( ...
                'x = 1   ', '% comment', 'Preserve');

            testCase.verifyEqual(comment, '   % comment');
        end

        function testNormalizeInlineCommentSpacingDoesNotCopyCodeSpaces(testCase)
            comment = MBeautifier.LineFormattingStages.preserveInlineCommentSpacing( ...
                'x = 1   ', '% comment', 'Normalize');

            testCase.verifyEqual(comment, '% comment');
        end

        function testReadableDeclarationSpacing(testCase)
            [formatted, wasHandled] = MBeautifier.LineFormattingStages.formatDeclarationLine( ...
                'x(1,1) double{mustBeFinite}=""', 'Readable');

            testCase.verifyTrue(wasHandled);
            testCase.verifyEqual(formatted, 'x (1,1) double {mustBeFinite} = ""');
        end

        function testCompactDeclarationSpacing(testCase)
            [formatted, wasHandled] = MBeautifier.LineFormattingStages.formatDeclarationLine( ...
                'x (1,1) double {mustBeFinite} = ""', 'Compact');

            testCase.verifyTrue(wasHandled);
            testCase.verifyEqual(formatted, 'x(1,1) double{mustBeFinite} = ""');
        end

        function testDeclarationFallbackIsExplicit(testCase)
            [formatted, wasHandled] = MBeautifier.LineFormattingStages.formatDeclarationLine( ...
                '1invalid = value', 'Readable');

            testCase.verifyFalse(wasHandled);
            testCase.verifyEqual(formatted, '1invalid = value');
        end
    end
end
