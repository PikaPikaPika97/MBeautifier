classdef FormatterTestUtils
    %FORMATTERTESTUTILS Shared helpers for MBeautifier tests.

    methods (Static)
        function root = repoRoot()
            helperRoot = fileparts(mfilename('fullpath'));
            testsRoot = fileparts(helperRoot);
            root = fileparts(testsRoot);
        end

        function path = fixturePath(name)
            path = fullfile(FormatterTestUtils.repoRoot(), 'resources', 'testdata', name);
        end

        function text = readText(path)
            text = fileread(path);
        end

        function text = readFixture(name)
            text = FormatterTestUtils.readText(FormatterTestUtils.fixturePath(name));
        end

        function text = normalizeText(text)
            text = strrep(text, sprintf('\r'), '');
        end

        function path = baseConfigurationPath()
            path = fullfile(FormatterTestUtils.repoRoot(), 'resources', 'settings', 'MBeautyConfigurationRules.xml');
        end

        function config = loadConfiguration(overrides)
            if nargin < 1
                overrides = struct();
            end

            configPath = FormatterTestUtils.createConfigurationCopy(overrides);
            config = MBeautifier.Configuration.Configuration.fromFile(configPath);
        end

        function formatted = formatText(text, overrides)
            if nargin < 2
                overrides = struct();
            end

            configuration = FormatterTestUtils.loadConfiguration(overrides);
            formatted = MBeautifier.FormattingPipeline.formatText(text, configuration);
        end

        function indented = indentText(text, overrides)
            if nargin < 2
                overrides = struct();
            end

            configuration = FormatterTestUtils.loadConfiguration(overrides);
            indenter = MBeautifier.MIndenter(configuration);
            indented = indenter.performIndenting(text);
        end

        function directory = createTempDirectory()
            directory = tempname();
            mkdir(directory);
        end

        function path = writeTempTextFile(fileName, text)
            directory = FormatterTestUtils.createTempDirectory();
            path = fullfile(directory, fileName);
            FormatterTestUtils.writeTextFile(path, text);
        end

        function path = copyFixtureToTemp(name)
            directory = FormatterTestUtils.createTempDirectory();
            path = fullfile(directory, name);
            copyfile(FormatterTestUtils.fixturePath(name), path);
        end
    end

    methods (Static, Access = private)
        function path = createConfigurationCopy(overrides)
            text = FormatterTestUtils.readText(FormatterTestUtils.baseConfigurationPath());
            keys = fieldnames(overrides);

            for idx = 1:numel(keys)
                key = keys{idx};
                value = overrides.(key);
                replacement = FormatterTestUtils.specialRuleBlock(key, value);
                pattern = ['<SpecialRule>\s*<Key>', regexptranslate('escape', key), ...
                    '</Key>\s*<Value>[^<]*</Value>\s*</SpecialRule>'];
                [startIndex, endIndex] = regexp(text, pattern, 'once');

                if isempty(startIndex)
                    insertIndex = regexp(text, '</SpecialRules>', 'once');
                    text = [text(1:insertIndex-1), replacement, newline, text(insertIndex:end)];
                else
                    text = [text(1:startIndex-1), replacement, text(endIndex+1:end)];
                end
            end

            path = FormatterTestUtils.writeTempTextFile('MBeautyConfigurationRules.xml', text);
        end

        function block = specialRuleBlock(key, value)
            block = sprintf([ ...
                '      <SpecialRule>\n', ...
                '         <Key>%s</Key>\n', ...
                '         <Value>%s</Value>\n', ...
                '      </SpecialRule>'], key, value);
        end

        function writeTextFile(path, text)
            fid = fopen(path, 'wt');
            cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
            fprintf(fid, '%s', text);
        end
    end
end
