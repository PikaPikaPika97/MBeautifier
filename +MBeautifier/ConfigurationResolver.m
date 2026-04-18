classdef ConfigurationResolver
    %CONFIGURATIONRESOLVER Resolve formatter configuration for each entry point.

    methods (Static)
        function configuration = resolveForText(varargin)
            options = MBeautifier.ConfigurationResolver.parseOptions(varargin{:});
            configuration = MBeautifier.ConfigurationResolver.resolveWithOptions(options, '');
        end

        function configuration = resolveForFile(file, varargin)
            options = MBeautifier.ConfigurationResolver.parseOptions(varargin{:});
            configuration = MBeautifier.ConfigurationResolver.resolveWithOptions(options, fileparts(file));
        end

        function configuration = resolveForEditorDocument(document, varargin)
            options = MBeautifier.ConfigurationResolver.parseOptions(varargin{:});
            configuration = [];

            fileName = MBeautifier.DesktopAdapter.getFilename(document);
            if exist(fileName, 'file') == 2
                configuration = MBeautifier.ConfigurationResolver.resolveWithOptions(options, fileparts(fileName));
            end

            if isempty(configuration)
                configuration = MBeautifier.ConfigurationResolver.resolveWithOptions(options, '');
            end
        end

        function configuration = defaultConfiguration()
            rulesXmlFileFull = MBeautifier.ConfigurationResolver.rulesXmlFileFull();
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

        function options = parseOptions(varargin)
            options = struct('Configuration', [], 'ConfigurationFile', '');

            if isempty(varargin)
                return;
            end

            if mod(numel(varargin), 2) ~= 0
                error('MBeautifier:Configuration:InvalidArguments', ...
                    'Configuration options must be provided as name-value pairs.');
            end

            for idx = 1:2:numel(varargin)
                optionName = varargin{idx};
                optionValue = varargin{idx+1};

                if isstring(optionName)
                    if isscalar(optionName)
                        optionName = char(optionName);
                    else
                        error('MBeautifier:Configuration:InvalidOptionName', ...
                            'Configuration option names must be scalar strings or character vectors.');
                    end
                end

                if ~ischar(optionName)
                    error('MBeautifier:Configuration:InvalidOptionName', ...
                        'Configuration option names must be character vectors.');
                end

                switch lower(strtrim(optionName))
                    case 'configuration'
                        if ~isempty(optionValue) && ...
                                ~isa(optionValue, 'MBeautifier.Configuration.Configuration')
                            error('MBeautifier:Configuration:InvalidConfigurationObject', ...
                                'The "Configuration" option must be a MBeautifier.Configuration.Configuration object.');
                        end

                        options.Configuration = optionValue;

                    case 'configurationfile'
                        options.ConfigurationFile = ...
                            MBeautifier.ConfigurationResolver.normalizePathLikeValue(optionValue, ...
                            'MBeautifier:Configuration:InvalidConfigurationFile');

                    otherwise
                        error('MBeautifier:Configuration:UnknownOption', ...
                            'Unknown configuration option "%s".', optionName);
                end
            end
        end
    end

    methods (Static, Access = private)
        function configuration = resolveWithOptions(options, startDirectory)
            if ~isempty(options.Configuration)
                configuration = options.Configuration;
                return;
            end

            if ~isempty(options.ConfigurationFile)
                configuration = MBeautifier.ConfigurationResolver.loadConfigurationFromFile(options.ConfigurationFile);
                return;
            end

            configurationFile = '';
            if ~isempty(startDirectory) && exist(startDirectory, 'dir') == 7
                configurationFile = MBeautifier.ConfigurationResolver.findProjectConfigurationFile(startDirectory);
            end

            if isempty(configurationFile)
                configuration = MBeautifier.ConfigurationResolver.defaultConfiguration();
            else
                configuration = MBeautifier.ConfigurationResolver.loadConfigurationFromFile(configurationFile);
            end
        end

        function configuration = loadConfigurationFromFile(configurationFile)
            if exist(configurationFile, 'file') ~= 2
                error('MBeautifier:Configuration:ConfigurationFileDoesNotExist', ...
                    'The configuration file "%s" does not exist.', configurationFile);
            end

            configuration = MBeautifier.Configuration.Configuration.fromFile(configurationFile);
        end

        function configurationFile = findProjectConfigurationFile(startDirectory)
            configurationFile = '';
            currentDirectory = startDirectory;

            while ~isempty(currentDirectory) && exist(currentDirectory, 'dir') == 7
                candidate = fullfile(currentDirectory, '.mbeautifier.xml');
                if exist(candidate, 'file') == 2
                    configurationFile = candidate;
                    return;
                end

                parentDirectory = fileparts(currentDirectory);
                if isempty(parentDirectory) || strcmp(parentDirectory, currentDirectory)
                    return;
                end

                currentDirectory = parentDirectory;
            end
        end

        function path = rulesXmlFileFull()
            path = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
                'resources', 'settings', 'MBeautyConfigurationRules.xml');
        end

        function value = normalizePathLikeValue(optionValue, errorId)
            if isstring(optionValue)
                if isscalar(optionValue)
                    optionValue = char(optionValue);
                else
                    error(errorId, 'The configuration file option must be a scalar string or character vector.');
                end
            end

            if ~ischar(optionValue)
                error(errorId, 'The configuration file option must be a character vector.');
            end

            value = strtrim(optionValue);
        end
    end
end
