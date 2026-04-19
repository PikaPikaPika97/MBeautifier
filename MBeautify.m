classdef MBeautify
    % Provides static methods to perform code formatting targeting text,
    % file(s), the currently active editor page or the current selection in
    % editor.
    %   The rules of the formatting are defined in the "MBeautyConfigurationRules.xml" in the resources directory. This
    %   file can be modified to affect the formatting.
    %
    %   Example usage:
    %
    %   MBeautify.formatCurrentEditorPage(); % Formats the current page in editor without saving
    %   MBeautify.formatCurrentEditorPage(); % Formats the current page in editor with saving
    %   MBeautify.formatFile('D:\testFile.m', 'D:\testFileNew.m'); % Formats the first file into the second file without opening it in the Editor
    %   MBeautify.formatFile('D:\testFile.m', 'D:\testFile.m'); % Formats the first file in-place without opening it in the Editor
    %   MBeautify.formatFiles('D:\mydir', '*.m'); % Formats all files in the specified diretory in-place
    %
    %   Shortcuts:
    %
    %   Shortcuts can be automatically created for "formatCurrentEditorPage" and "formatEditorSelection" by executing
    %   MBeautify.createShortcut() with the parameter 'editorpage' or 'editorselection'.
    
    %% Public API
    
    methods (Static = true)
        
        function formatFileNoEditor(file, varargin)
            % Format file outside of editor
            % function formatFileNoEditor(file, outFile)
            %
            % Formats the file specified in the first argument. If the
            % second argument is also specified, the formatted source is
            % saved to this file. The input and the output file can be the
            % same, in which case the format operation is carried out
            % in-place.
            %
            [outFile, optionArgs] = MBeautify.extractOptionalOutputPath(varargin);

            if isempty(outFile)
                MBeautifier.FormattingPipeline.formatFileNoEditor(file, optionArgs{:});
            else
                MBeautifier.FormattingPipeline.formatFileNoEditor(file, outFile, optionArgs{:});
            end
        end

        function formattedText = formatText(text, varargin)
            % Format plain MATLAB source text without editor integration.
            formattedText = MBeautifier.FormattingPipeline.formatTextWithResolvedConfiguration(text, varargin{:});
        end
        
        function formatFile(file, varargin)
            % Format file outside of editor.
            % function formatFile(file, outFile)
            %
            % Formats the file specified in the first argument. If the second
            % argument is also specified, the formatted source is saved to this
            % file. The input and the output file can be the same.
            [outFile, optionArgs] = MBeautify.extractOptionalOutputPath(varargin);

            if isempty(outFile)
                MBeautifier.FormattingPipeline.formatFileNoEditor(file, optionArgs{:});
            else
                MBeautifier.FormattingPipeline.formatFileNoEditor(file, outFile, optionArgs{:});
            end
        end
        
        function formatFiles(directory, varargin)
            % Format multiple files in-place. Supports file type filtering and subfolder recursion
            % function formatFiles(directory, fileFilter, recurse)
            %
            % Formats the files in-place (files are overwritten) in the
            % specified directory, collected by the specified filter and optionally recurse subfolders.
            % The file filter is a wildcard expression used by the dir
            % command. Defaults to '*.m'
            %
            % Recurse defaults to false. Set true to recurse subfolders of directory.
            % Editor defaults to false. Set to true to format files through the editor integration.
            [fileFilter, recurse, editor, optionArgs] = MBeautify.parseBatchArguments(varargin, false);

            MBeautifier.FormattingPipeline.formatFiles(directory, fileFilter, recurse, editor, optionArgs{:});
        end

        function result = checkFile(file, varargin)
            % Inspect a file without rewriting it.
            [editor, optionArgs] = MBeautify.extractEditorOption(varargin, false);
            result = MBeautifier.FormattingPipeline.checkFile(file, editor, optionArgs{:});
        end

        function result = diffFile(file, varargin)
            % Return a lightweight diff summary for a file without rewriting it.
            [editor, optionArgs] = MBeautify.extractEditorOption(varargin, false);
            result = MBeautifier.FormattingPipeline.diffFile(file, editor, optionArgs{:});
        end

        function result = checkFiles(directory, varargin)
            % Inspect multiple files without rewriting them.
            [fileFilter, recurse, editor, optionArgs] = MBeautify.parseBatchArguments(varargin, false);
            result = MBeautifier.FormattingPipeline.checkFiles(directory, fileFilter, recurse, editor, optionArgs{:});
        end

        function result = diffFiles(directory, varargin)
            % Return lightweight diff summaries for multiple files without rewriting them.
            [fileFilter, recurse, editor, optionArgs] = MBeautify.parseBatchArguments(varargin, false);
            result = MBeautifier.FormattingPipeline.diffFiles(directory, fileFilter, recurse, editor, optionArgs{:});
        end
        
        function formatEditorSelection(doSave)
            %
            % function formatEditorSelection(doSave)
            %
            % Performs formatting on selection of the currently active Matlab Editor page.
            % The selection is automatically extended until the first empty line above and below.
            % This method can be useful for large files, but using "formatCurrentEditorPage" is always suggested.
            % Optionally saves the file (if it is possible) and it is forced on the first argument (true). By default
            % the file is not saved.
            
            if nargin == 0
                MBeautifier.EditorApp.formatEditorSelection();
            else
                MBeautifier.EditorApp.formatEditorSelection(doSave);
            end
        end
        
        function formatCurrentEditorPage(doSave)
            % Performs formatting on the currently active Matlab Editor page.
            % function formatCurrentEditorPage(doSave)
            %
            % Optionally saves the file (if it is possible) and it is forced on the first argument (true). By default
            % the file is not saved.
            
            if nargin == 0
                MBeautifier.EditorApp.formatCurrentEditorPage();
            else
                MBeautifier.EditorApp.formatCurrentEditorPage(doSave);
            end
        end
        
        function createShortcut(mode)
            % Adds MBeauty to path and creates shortcut in Matlab editor
            % function createShortcut(mode)
            %
            % Creates a shortcut with the selected mode: 'editorpage', 'editorselection', 'file'. The shortcut adds
            % MBeauty to the Matlab path and executes the following command:
            %   'editorpage' - MBeauty.formatCurrentEditorPage
            %   'editorselection' - MBeauty.formatEditorSelection
            %   'file' - MBeauty.formatFile
            
            MBeautyShortcuts.createShortcut(mode);
        end
    end

    methods (Static, Access = private)
        function [outFile, optionArgs] = extractOptionalOutputPath(args)
            outFile = [];
            optionArgs = args;

            if isempty(args)
                return;
            end

            if MBeautify.isOptionName(args{1})
                return;
            end

            outFile = args{1};
            optionArgs = args(2:end);
        end

        function [fileFilter, recurse, editor, optionArgs] = parseBatchArguments(args, defaultEditor)
            optionStart = numel(args) + 1;
            for idx = 1:numel(args)
                if MBeautify.isOptionName(args{idx})
                    optionStart = idx;
                    break;
                end
            end

            positionalArgs = args(1:optionStart-1);
            optionArgs = args(optionStart:end);

            fileFilter = '*.m';
            recurse = false;
            editor = defaultEditor;

            if numel(positionalArgs) > 3
                error('MBeautifier:InvalidBatchArguments', ...
                    'Too many positional batch formatting arguments were provided.');
            end

            if numel(positionalArgs) >= 1
                fileFilter = positionalArgs{1};
            end

            if numel(positionalArgs) >= 2
                recurse = positionalArgs{2};
            end

            if numel(positionalArgs) >= 3
                editor = positionalArgs{3};
            end

            [editor, optionArgs] = MBeautify.extractEditorOption(optionArgs, editor);
        end

        function [editor, optionArgs] = extractEditorOption(args, defaultEditor)
            editor = defaultEditor;
            optionArgs = {};

            if isempty(args)
                return;
            end

            if mod(numel(args), 2) ~= 0
                error('MBeautifier:InvalidNameValueArguments', ...
                    'Name-value arguments must be provided in pairs.');
            end

            for idx = 1:2:numel(args)
                optionName = args{idx};
                optionValue = args{idx+1};

                if MBeautify.isNamedOption(optionName, 'editor')
                    if ~(isscalar(optionValue) && (islogical(optionValue) || isnumeric(optionValue)))
                        error('MBeautifier:IllegalOption:Editor', ...
                            'The "Editor" option must be a logical scalar.');
                    end

                    editor = logical(optionValue);
                else
                    optionArgs = [optionArgs, args(idx:idx+1)]; %#ok<AGROW>
                end
            end
        end

        function tf = isOptionName(value)
            tf = MBeautify.isNamedOption(value, 'configuration') || ...
                MBeautify.isNamedOption(value, 'configurationfile') || ...
                MBeautify.isNamedOption(value, 'editor');
        end

        function tf = isNamedOption(value, optionName)
            tf = false;

            if isstring(value)
                if isscalar(value)
                    value = char(value);
                else
                    return;
                end
            end

            if ischar(value)
                tf = strcmpi(strtrim(value), optionName);
            end
        end
    end
end
