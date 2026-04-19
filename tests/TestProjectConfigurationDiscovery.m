classdef TestProjectConfigurationDiscovery < matlab.unittest.TestCase
    %TESTPROJECTCONFIGURATIONDISCOVERY Coverage for project-local configuration lookup.

    methods (Test)
        function testFormatFileNoEditorUsesNearestProjectConfiguration(testCase)
            projectRoot = FormatterTestUtils.createTempDirectory();
            nestedDirectory = fullfile(projectRoot, 'src', 'nested');
            mkdir(nestedDirectory);
            testCase.addTeardown(@() rmdir(projectRoot, 's'));

            FormatterTestUtils.writeProjectConfiguration(projectRoot, ...
                struct('InlineCommentSpacingStrategy', 'Preserve'));
            inputPath = fullfile(nestedDirectory, 'projectConfigInput.m');
            outputPath = fullfile(nestedDirectory, 'projectConfigOutput.m');
            input = sprintf('x = 1   %% comment\n');
            FormatterTestUtils.writeTextFileForTest(inputPath, input);

            MBeautify.formatFileNoEditor(inputPath, outputPath);

            testCase.verifyEqual( ...
                FormatterTestUtils.normalizeText(FormatterTestUtils.readText(outputPath)), ...
                FormatterTestUtils.normalizeText(input));
        end

        function testExplicitConfigurationOverridesProjectConfiguration(testCase)
            projectRoot = FormatterTestUtils.createTempDirectory();
            nestedDirectory = fullfile(projectRoot, 'src');
            mkdir(nestedDirectory);
            testCase.addTeardown(@() rmdir(projectRoot, 's'));

            FormatterTestUtils.writeProjectConfiguration(projectRoot, ...
                struct('InlineCommentSpacingStrategy', 'Normalize'));
            inputPath = fullfile(nestedDirectory, 'overrideInput.m');
            outputPath = fullfile(nestedDirectory, 'overrideOutput.m');
            input = sprintf('x = 1   %% comment\n');
            configuration = FormatterTestUtils.loadConfiguration( ...
                struct('InlineCommentSpacingStrategy', 'Preserve'));
            FormatterTestUtils.writeTextFileForTest(inputPath, input);

            MBeautify.formatFileNoEditor(inputPath, outputPath, 'Configuration', configuration);

            testCase.verifyEqual( ...
                FormatterTestUtils.normalizeText(FormatterTestUtils.readText(outputPath)), ...
                FormatterTestUtils.normalizeText(input));
        end

        function testFormatCurrentEditorPageUsesProjectConfigurationForSavedDocument(testCase)
            projectRoot = FormatterTestUtils.createTempDirectory();
            nestedDirectory = fullfile(projectRoot, 'src');
            mkdir(nestedDirectory);
            testCase.addTeardown(@() rmdir(projectRoot, 's'));

            FormatterTestUtils.writeProjectConfiguration(projectRoot, ...
                struct('InlineCommentSpacingStrategy', 'Preserve'));
            inputPath = fullfile(nestedDirectory, 'savedEditorConfig.m');
            input = sprintf('x = 1   %% comment\n');
            FormatterTestUtils.writeTextFileForTest(inputPath, input);

            document = matlab.desktop.editor.openDocument(inputPath);
            testCase.addTeardown(@() TestProjectConfigurationDiscovery.closeIfValid(document));
            document.makeActive();

            MBeautify.formatCurrentEditorPage();

            testCase.verifyEqual( ...
                FormatterTestUtils.normalizeText(document.Text), ...
                FormatterTestUtils.normalizeText(input));
        end

        function testUnsavedEditorDocumentFallsBackToDefaultConfiguration(testCase)
            input = sprintf('x = 1   %% comment\n');
            expected = FormatterTestUtils.formatText(input);
            document = MBeautifier.DesktopAdapter.newDocument(input);
            testCase.addTeardown(@() TestProjectConfigurationDiscovery.closeIfValid(document));
            document.makeActive();

            MBeautify.formatCurrentEditorPage();

            testCase.verifyEqual( ...
                FormatterTestUtils.normalizeText(document.Text), ...
                FormatterTestUtils.normalizeText(expected));
        end
    end

    methods (Static, Access = private)
        function closeIfValid(document)
            if ~isempty(document) && isvalid(document)
                document.close();
                drawnow();
            end
        end
    end
end
