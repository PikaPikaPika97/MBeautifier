classdef TestEditorIntegrationState < matlab.unittest.TestCase
    %TESTEDITORINTEGRATIONSTATE Coverage for editor integration state handling.

    methods (Test)
        function testFormatCurrentEditorPageFormatsActiveDocument(testCase)
            originalText = sprintf('function y=foo(x)\ny=x+1;\nend\n');
            expectedText = FormatterTestUtils.formatText(originalText);
            document = EditorTestUtils.openTemporaryDocument(testCase, ...
                'testFormatCurrentEditorPage.m', originalText);
            MBeautifier.DesktopAdapter.activateDocument(document);

            MBeautify.formatCurrentEditorPage();

            testCase.verifyEqual( ...
                FormatterTestUtils.normalizeText(MBeautifier.DesktopAdapter.getText(document)), ...
                FormatterTestUtils.normalizeText(expectedText));
        end

        function testFormatEditorSelectionFormatsOnlyTheExpandedBlock(testCase)
            originalText = sprintf([ ...
                'a = 1;\n', ...
                '\n', ...
                'function y=foo(x)\n', ...
                'y=x+1;\n', ...
                'end\n', ...
                '\n', ...
                'c = 3;\n']);
            expectedBlock = FormatterTestUtils.formatText(sprintf('function y=foo(x)\ny=x+1;\nend\n'));
            expectedText = sprintf('a = 1;\n\n%s\nc = 3;\n', expectedBlock);

            document = EditorTestUtils.openTemporaryDocument(testCase, ...
                'testFormatEditorSelection.m', originalText);
            MBeautifier.DesktopAdapter.setSelection(document, [4, 1, 4, Inf]);
            MBeautifier.DesktopAdapter.activateDocument(document);

            MBeautify.formatEditorSelection();

            testCase.verifyEqual( ...
                FormatterTestUtils.normalizeText(MBeautifier.DesktopAdapter.getText(document)), ...
                FormatterTestUtils.normalizeText(expectedText));
        end

        function testFormatFileUsesHeadlessPipelineWithoutOpeningDocuments(testCase)
            inputText = sprintf('function y=foo(x)\ny=x+1;\nend\n');
            inputPath = FormatterTestUtils.writeTempTextFile('testFormatFileInput.m', inputText);
            outputPath = fullfile(fileparts(inputPath), 'testFormatFileOutput.m');
            FormatterTestUtils.writeTextFileForTest(outputPath, 'placeholder');
            expectedText = FormatterTestUtils.formatText(inputText);

            testCase.addTeardown(@() EditorTestUtils.deleteIfExists(outputPath));
            testCase.verifyFalse(MBeautifier.DesktopAdapter.isDocumentOpen(inputPath));
            testCase.verifyFalse(MBeautifier.DesktopAdapter.isDocumentOpen(outputPath));

            MBeautify.formatFile(inputPath, outputPath);

            testCase.verifyEqual( ...
                FormatterTestUtils.normalizeText(FormatterTestUtils.readText(outputPath)), ...
                FormatterTestUtils.normalizeText(expectedText));
            testCase.verifyFalse(MBeautifier.DesktopAdapter.isDocumentOpen(inputPath));
            testCase.verifyFalse(MBeautifier.DesktopAdapter.isDocumentOpen(outputPath));
        end
    end
end
