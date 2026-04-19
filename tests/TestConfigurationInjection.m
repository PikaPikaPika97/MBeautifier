classdef TestConfigurationInjection < matlab.unittest.TestCase
    %TESTCONFIGURATIONINJECTION Coverage for explicit configuration options.

    methods (Test)
        function testFormatTextUsesExplicitConfigurationObject(testCase)
            input = sprintf('x = 1   %% comment\n');
            configuration = FormatterTestUtils.loadConfiguration( ...
                struct('InlineCommentSpacingStrategy', 'Preserve'));

            formatted = MBeautify.formatText(input, 'Configuration', configuration);

            testCase.verifyEqual( ...
                FormatterTestUtils.normalizeText(formatted), ...
                FormatterTestUtils.normalizeText(input));
        end

        function testFormatFileUsesExplicitConfigurationFile(testCase)
            directory = FormatterTestUtils.createTempDirectory();
            testCase.addTeardown(@() rmdir(directory, 's'));

            inputPath = fullfile(directory, 'formatConfigInput.m');
            outputPath = fullfile(directory, 'formatConfigOutput.m');
            configurationPath = FormatterTestUtils.writeConfigurationFile(directory, ...
                'custom_config.xml', struct('InlineCommentSpacingStrategy', 'Preserve'));
            input = sprintf('x = 1   %% comment\n');

            FormatterTestUtils.writeTextFileForTest(inputPath, input);
            MBeautify.formatFile(inputPath, outputPath, 'ConfigurationFile', configurationPath);

            testCase.verifyEqual( ...
                FormatterTestUtils.normalizeText(FormatterTestUtils.readText(outputPath)), ...
                FormatterTestUtils.normalizeText(input));
        end

        function testCheckFileUsesExplicitConfigurationObject(testCase)
            file = FormatterTestUtils.writeTempTextFile('checkConfigInput.m', ...
                sprintf('clc; clear; close all;\n'));
            configuration = FormatterTestUtils.loadConfiguration( ...
                struct('StatementBreakStrategy', 'Never'));

            result = MBeautify.checkFile(file, 'Configuration', configuration);

            testCase.verifyFalse(result.changed);
            testCase.verifyEqual(result.status, 'unchanged');
        end
    end
end
