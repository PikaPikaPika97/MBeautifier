classdef FormattingPipeline
    %FORMATTINGPIPELINE Core text and file formatting helpers.

    methods (Static)
        function formatFileNoEditor(file, outFile)
            MBeautifier.FormattingPipeline.requireExistingFile(file);

            text = fileread(file);
            configuration = MBeautifier.FormattingPipeline.getConfiguration();
            text = MBeautifier.FormattingPipeline.formatText(text, configuration);

            if nargin < 2
                outFile = file;
            end

            MBeautifier.FormattingPipeline.writeTextFile(outFile, text);
        end

        function formatFiles(directory, fileFilter, recurse, editor)
            MBeautifier.FormattingPipeline.requireExistingDirectory(directory);

            files = MBeautifier.FormattingPipeline.collectFiles(directory, fileFilter, recurse);
            for iF = 1:numel(files)
                file = fullfile(files(iF).folder, files(iF).name);
                MBeautifier.FormattingPipeline.formatFileInPlace(file, editor);
            end
        end

        function formattedText = formatText(text, configuration)
            % Format and indent plain text using the active configuration.
            formatter = MBeautifier.MFormatter(configuration);
            indenter = MBeautifier.MIndenter(configuration);
            formattedText = formatter.performFormatting(text);
            formattedText = indenter.performIndenting(formattedText);
        end

        function requireExistingFile(file)
            if exist(file, 'file') ~= 2
                error('MBeautifier:FileDoesNotExist', ...
                    'The file "%s" does not exist. Provide an existing MATLAB file to format.', file);
            end
        end

        function requireExistingDirectory(directory)
            if exist(directory, 'dir') ~= 7
                error('MBeautifier:DirectoryDoesNotExist', ...
                    'The directory "%s" does not exist. Provide an existing directory to format.', directory);
            end
        end

        function writeTextFile(path, text)
            [fid, errorMessage] = fopen(path, 'wt');
            if fid == -1
                error('MBeautifier:OutputFileNotWritable', ...
                    'Unable to open "%s" for writing. %s', path, errorMessage);
            end
            fileCloser = onCleanup(@() fclose(fid));
            fprintf(fid, '%s', text); %#ok<NASGU>
        end

        function configuration = getConfiguration()
            % Load and cache the active formatter configuration.
            rulesXmlFileFull = MBeautifier.FormattingPipeline.rulesXmlFileFull();
            [parent, file, ext] = fileparts(rulesXmlFileFull);
            path = java.nio.file.Paths.get(parent, [file, ext]);

            if ~path.toFile.exists()
                error('MBeautifier:Configuration:ConfigurationFileDoesNotExist', ...
                    'The configuration XML file is missing!');
            end

            bytes = java.nio.file.Files.readAllBytes(path);
            md = java.security.MessageDigest.getInstance('md5');
            currentChecksum = javax.xml.bind.DatatypeConverter.printHexBinary(md.digest(bytes));
            storedChecksum = getappdata(0, 'MBeautifier_ConfigurationChecksum');
            if isempty(storedChecksum)
                storedChecksum = '';
            end

            configuration = [];
            if strcmpi(currentChecksum, storedChecksum)
                configuration = getappdata(0, 'MBeautifier_ConfigurationObject');
            end

            if isempty(configuration)
                configuration = MBeautifier.Configuration.Configuration.fromFile(rulesXmlFileFull);
                setappdata(0, 'MBeautifier_ConfigurationChecksum', currentChecksum);
                setappdata(0, 'MBeautifier_ConfigurationObject', configuration);
            end
        end
    end

    methods (Static, Access = private)
        function files = collectFiles(directory, fileFilter, recurse)
            if recurse
                directory = fullfile(directory, '**');
            end

            files = dir(fullfile(directory, fileFilter));
        end

        function formatFileInPlace(file, useEditor)
            if useEditor
                MBeautifier.EditorApp.formatFile(file, file);
            else
                MBeautifier.FormattingPipeline.formatFileNoEditor(file, file);
            end
        end

        function path = rulesXmlFileFull()
            path = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
                'resources', 'settings', 'MBeautyConfigurationRules.xml');
        end
    end
end
