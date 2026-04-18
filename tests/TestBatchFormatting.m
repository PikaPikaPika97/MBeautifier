classdef TestBatchFormatting < matlab.unittest.TestCase
    %TESTBATCHFORMATTING Coverage for batch formatting entry points.

    methods (Test)
        function testFormatFilesErrorsForMissingDirectory(testCase)
            missingDirectory = fullfile(tempdir, 'mbeautifier_missing_directory');
            testCase.verifyError(@() MBeautify.formatFiles(missingDirectory, '*.m', false, false), ...
                'MBeautifier:DirectoryDoesNotExist');
        end

        function testFormatFilesFormatsRootFilesWithoutEditor(testCase)
            directory = TestBatchFormatting.createBatchDirectory(testCase);
            rootFile = TestBatchFormatting.writeTextFile(directory, 'rootFile.m', ...
                sprintf('function y=foo(x)\ny=x+1;\nend\n'));
            nestedDirectory = fullfile(directory, 'nested');
            mkdir(nestedDirectory);
            nestedFile = TestBatchFormatting.writeTextFile(nestedDirectory, 'nestedFile.m', ...
                sprintf('function y=bar(x)\ny=x+2;\nend\n'));

            expectedRoot = FormatterTestUtils.formatText(FormatterTestUtils.readText(rootFile));
            originalNested = FormatterTestUtils.readText(nestedFile);

            MBeautify.formatFiles(directory, '*.m', false, false);

            testCase.verifyEqual( ...
                FormatterTestUtils.normalizeText(FormatterTestUtils.readText(rootFile)), ...
                FormatterTestUtils.normalizeText(expectedRoot));
            testCase.verifyEqual( ...
                FormatterTestUtils.normalizeText(FormatterTestUtils.readText(nestedFile)), ...
                FormatterTestUtils.normalizeText(originalNested));
        end

        function testFormatFilesRecursesWithoutEditor(testCase)
            directory = TestBatchFormatting.createBatchDirectory(testCase);
            rootFile = TestBatchFormatting.writeTextFile(directory, 'rootFile.m', ...
                sprintf('function y=foo(x)\ny=x+1;\nend\n'));
            nestedDirectory = fullfile(directory, 'nested');
            mkdir(nestedDirectory);
            nestedFile = TestBatchFormatting.writeTextFile(nestedDirectory, 'nestedFile.m', ...
                sprintf('function y=bar(x)\ny=x+2;\nend\n'));

            expectedRoot = FormatterTestUtils.formatText(FormatterTestUtils.readText(rootFile));
            expectedNested = FormatterTestUtils.formatText(FormatterTestUtils.readText(nestedFile));

            MBeautify.formatFiles(directory, '*.m', true, false);

            testCase.verifyEqual( ...
                FormatterTestUtils.normalizeText(FormatterTestUtils.readText(rootFile)), ...
                FormatterTestUtils.normalizeText(expectedRoot));
            testCase.verifyEqual( ...
                FormatterTestUtils.normalizeText(FormatterTestUtils.readText(nestedFile)), ...
                FormatterTestUtils.normalizeText(expectedNested));
        end

        function testFormatFilesIgnoresUnmatchedFilter(testCase)
            directory = TestBatchFormatting.createBatchDirectory(testCase);
            textFile = TestBatchFormatting.writeTextFile(directory, 'notes.txt', 'leave me alone');

            MBeautify.formatFiles(directory, '*.m', false, false);

            testCase.verifyEqual(FormatterTestUtils.readText(textFile), 'leave me alone');
        end
    end

    methods (Static, Access = private)
        function directory = createBatchDirectory(testCase)
            directory = tempname();
            mkdir(directory);
            testCase.addTeardown(@() rmdir(directory, 's'));
        end

        function path = writeTextFile(directory, fileName, text)
            path = fullfile(directory, fileName);
            fid = fopen(path, 'wt');
            fileCloser = onCleanup(@() fclose(fid)); %#ok<NASGU>
            fprintf(fid, '%s', text);
        end
    end
end
