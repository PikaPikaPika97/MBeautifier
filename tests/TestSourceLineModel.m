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

        function testIgnoresPercentInsideAdjacentCharacterArrays(testCase)
            analysis = MBeautifier.SourceLine.analyze('x = {''%d'' ''%f''}; % comment');

            testCase.verifyEqual(analysis.Code, 'x = {''%d'' ''%f''}; ');
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

        function testCodeWithoutStringsAndCommentsPreservesTranspose(testCase)
            codeLine = MBeautifier.SourceLine.codeWithoutStringsAndComments( ...
                'y = a'' + "not % comment" + ''also % text''; % comment');

            testCase.verifyNotEmpty(strfind(codeLine, 'a'''));
            testCase.verifyEmpty(strfind(codeLine, 'not'));
            testCase.verifyEmpty(strfind(codeLine, 'also'));
            testCase.verifyEmpty(strfind(codeLine, '% comment'));
        end

        function testContainerDepthDeltaIgnoresStringsAndComments(testCase)
            testCase.verifyEqual( ...
                MBeautifier.SourceLine.containerDepthDelta('value = "[" + ''{''; % ({['), 0);
            testCase.verifyEqual( ...
                MBeautifier.SourceLine.containerDepthDelta('value = outer([1, 2'), 2);
        end

        function testLeadingClosingContainerCountIgnoresStringContents(testCase)
            testCase.verifyEqual( ...
                MBeautifier.SourceLine.leadingClosingContainerCount('  ]) + "%]"'), 2);
            testCase.verifyEqual( ...
                MBeautifier.SourceLine.leadingClosingContainerCount('  "text")'), 0);
        end

        function testContinuationTokenDetectionUsesCodeView(testCase)
            testCase.verifyTrue(MBeautifier.SourceLine.endsWithContinuationToken('x = 1 + ... % comment'));
            testCase.verifyFalse(MBeautifier.SourceLine.endsWithContinuationToken('s = "..."'));
            testCase.verifyFalse(MBeautifier.SourceLine.endsWithContinuationToken('% ...'));
        end
    end
end
