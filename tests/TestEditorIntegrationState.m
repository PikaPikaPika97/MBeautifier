classdef TestEditorIntegrationState < matlab.unittest.TestCase
    %TESTEDITORINTEGRATIONSTATE Coverage for editor integration state handling.

    methods (Test)
        function testTemporaryEditorIndentPreferenceIsRestoredAfterError(testCase)
            configuration = FormatterTestUtils.loadConfiguration( ...
                struct('Indentation_Strategy', 'nestedfunctions'));
            originalPreference = MBeautifier.EditorApp.getEditorIndentPreference();
            testPreference = 'ClassicFunctionIndent';

            MBeautifier.EditorApp.setEditorIndentPreference(testPreference);
            cleanup = onCleanup(@() MBeautifier.EditorApp.setEditorIndentPreference(originalPreference)); %#ok<NASGU>

            testCase.verifyError( ...
                @() MBeautifier.EditorApp.runWithTemporaryEditorIndentPreference(configuration, ...
                @() error('MBeautifier:Test:ForcedFailure', 'Forced failure for cleanup verification.')), ...
                'MBeautifier:Test:ForcedFailure');

            testCase.verifyEqual(MBeautifier.EditorApp.getEditorIndentPreference(), testPreference);
        end

        function testFormatCurrentEditorPageFormatsActiveDocument(testCase)
            originalText = sprintf('function y=foo(x)\ny=x+1;\nend\n');
            expectedText = FormatterTestUtils.formatText(originalText);
            document = TestEditorIntegrationState.openTemporaryDocument(testCase, ...
                'testFormatCurrentEditorPage.m', originalText);
            document.makeActive();

            MBeautify.formatCurrentEditorPage();

            testCase.verifyEqual( ...
                FormatterTestUtils.normalizeText(document.Text), ...
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

            document = TestEditorIntegrationState.openTemporaryDocument(testCase, ...
                'testFormatEditorSelection.m', originalText);
            document.Selection = [4, 1, 4, Inf];
            document.makeActive();

            MBeautify.formatEditorSelection();

            testCase.verifyEqual( ...
                FormatterTestUtils.normalizeText(document.Text), ...
                FormatterTestUtils.normalizeText(expectedText));
        end

        function testFormatFileUsesHeadlessPipelineWithoutOpeningDocuments(testCase)
            inputText = sprintf('function y=foo(x)\ny=x+1;\nend\n');
            inputPath = FormatterTestUtils.writeTempTextFile('testFormatFileInput.m', inputText);
            outputPath = fullfile(fileparts(inputPath), 'testFormatFileOutput.m');
            FormatterTestUtils.writeTextFileForTest(outputPath, 'placeholder');
            expectedText = FormatterTestUtils.formatText(inputText);

            testCase.addTeardown(@() TestEditorIntegrationState.deleteIfExists(outputPath));
            testCase.verifyFalse(matlab.desktop.editor.isOpen(inputPath));
            testCase.verifyFalse(matlab.desktop.editor.isOpen(outputPath));

            MBeautify.formatFile(inputPath, outputPath);

            testCase.verifyEqual( ...
                FormatterTestUtils.normalizeText(FormatterTestUtils.readText(outputPath)), ...
                FormatterTestUtils.normalizeText(expectedText));
            testCase.verifyFalse(matlab.desktop.editor.isOpen(inputPath));
            testCase.verifyFalse(matlab.desktop.editor.isOpen(outputPath));
        end
    end

    methods (Static, Access = private)
        function document = openTemporaryDocument(testCase, fileName, text)
            path = FormatterTestUtils.writeTempTextFile(fileName, text);
            document = matlab.desktop.editor.openDocument(path);

            testCase.addTeardown(@() TestEditorIntegrationState.closeDocumentIfOpen(document));
            testCase.addTeardown(@() TestEditorIntegrationState.deleteIfExists(path));
        end

        function closeDocumentIfOpen(document)
            if ~isempty(document) && isvalid(document)
                document.close();
            end
        end

        function deleteIfExists(path)
            if exist(path, 'file') == 2
                delete(path);
            end
        end
    end
end
