classdef TestSourceLineModel < matlab.unittest.TestCase
    %TESTSOURCELINEMODEL Coverage for SourceLine lexical splitting.

    methods (Test)
        function testSplitsInlineComment(testCase)
            analysis = MBeautifier.SourceLine.analyze('x = 1; % comment');

            testCase.verifyEqual(analysis.Code, 'x = 1; ');
            testCase.verifyEqual(analysis.Comment, '% comment');
        end

        function testIgnoresPercentInsideCharacterArray(testCase)
            analysis = MBeautifier.SourceLine.analyze('x = ''100%''; % comment');

            testCase.verifyEqual(analysis.Code, 'x = ''100%''; ');
            testCase.verifyEqual(analysis.Comment, '% comment');
        end

        function testIgnoresPercentInsideStringArray(testCase)
            analysis = MBeautifier.SourceLine.analyze('x = "100%"; % comment');

            testCase.verifyEqual(analysis.Code, 'x = "100%"; ');
            testCase.verifyEqual(analysis.Comment, '% comment');
        end

        function testTreatsPostfixQuoteAsTranspose(testCase)
            analysis = MBeautifier.SourceLine.analyze('x = a'' + 1; % comment');

            testCase.verifyEqual(analysis.Code, 'x = a'' + 1; ');
            testCase.verifyEqual(analysis.Comment, '% comment');
        end

        function testSplitsAfterContinuationToken(testCase)
            analysis = MBeautifier.SourceLine.analyze('x = foo(... % comment');

            testCase.verifyEqual(analysis.Code, 'x = foo(...');
            testCase.verifyEqual(analysis.Comment, '% comment');
        end

        function testTracksBlockCommentState(testCase)
            startBlock = MBeautifier.SourceLine.analyze('%{', false, 0);
            body = MBeautifier.SourceLine.analyze('inside block', ...
                startBlock.IsInBlockComment, startBlock.BlockCommentDepth);
            endBlock = MBeautifier.SourceLine.analyze('%}', ...
                body.IsInBlockComment, body.BlockCommentDepth);

            testCase.verifyTrue(startBlock.IsInBlockComment);
            testCase.verifyEqual(startBlock.BlockCommentDepth, 1);
            testCase.verifyEqual(body.Code, '');
            testCase.verifyEqual(body.Comment, 'inside block');
            testCase.verifyFalse(endBlock.IsInBlockComment);
            testCase.verifyEqual(endBlock.BlockCommentDepth, 0);
        end

        function testRecognizesSectionSeparator(testCase)
            analysis = MBeautifier.SourceLine.analyze('%% Section');

            testCase.verifyTrue(analysis.IsSectionSeparator);
            testCase.verifyEqual(analysis.Code, '');
            testCase.verifyEqual(analysis.Comment, '%% Section');
        end
    end
end
