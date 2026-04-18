classdef MBeautify
    % Provides static methods to perform code formatting targeting file(s), the currently active editor page or the
    % current selection in editor.
    %   The rules of the formatting are defined in the "MBeautyConfigurationRules.xml" in the resources directory. This
    %   file can be modified to affect the formatting.
    %
    %   Example usage:
    %
    %   MBeautify.formatCurrentEditorPage(); % Formats the current page in editor without saving
    %   MBeautify.formatCurrentEditorPage(); % Formats the current page in editor with saving
    %   MBeautify.formatFile('D:\testFile.m', 'D:\testFileNew.m'); % Formats the first file into the second file
    %   MBeautify.formatFile('D:\testFile.m', 'D:\testFile.m'); % Formats the first file in-place
    %   MBeautify.formatFiles('D:\mydir', '*.m'); % Formats all files in the specified diretory in-place
    %
    %   Shortcuts:
    %
    %   Shortcuts can be automatically created for "formatCurrentEditorPage", "formatEditorSelection" and
    %   "formatFile" methods by executing MBeautify.createShortcut() in order with the parameter 'editorpage',
    %   'editorselection' or 'file'.
    %   The created shortcuts add MBeauty to the Matlab path also (therefore no preparation of the path is needed additionally).
    
    %% Public API
    
    methods (Static = true)
        
        function formatFileNoEditor(file, outFile)
            % Format file outside of editor
            % function formatFileNoEditor(file, outFile)
            %
            % Formats the file specified in the first argument. If the
            % second argument is also specified, the formatted source is
            % saved to this file. The input and the output file can be the
            % same, in which case the format operation is carried out
            % in-place.
            %
            if nargin < 2
                MBeautifier.FormattingPipeline.formatFileNoEditor(file);
            else
                MBeautifier.FormattingPipeline.formatFileNoEditor(file, outFile);
            end
        end
        
        function formatFile(file, outFile)
            % Format file in editor
            % function formatFile(file, outFile)
            %
            % Formats the file specified in the first argument. The file is opened in the Matlab Editor. If the second
            % argument is also specified, the formatted source is saved to this file and it is closed if it wasn't already
            % open in the Editor. Otherwise the formatted input file remains opened in the Matlab Editor.
            % The input and the output file can be the same.
            if nargin < 2
                MBeautifier.EditorApp.formatFile(file);
            else
                MBeautifier.EditorApp.formatFile(file, outFile);
            end
        end
        
        function formatFiles(directory, fileFilter, recurse, editor)
            % Format multiple files in-place. Supports file type filtering and subfolder recursion
            % function formatFiles(directory, fileFilter, recurse)
            %
            % Formats the files in-place (files are overwritten) in the
            % specified directory, collected by the specified filter and optionally recurse subfolders.
            % The file filter is a wildcard expression used by the dir
            % command. Defaults to '*.m'
            %
            % Recurse defaults to false. Set true to recurse subfolders of directory.
            % Editor defaults to true.  Set to false to format files outside the editor.
            
            if nargin < 2
                fileFilter = '*.m';
            end
            
            if ~exist('recurse','var') || isempty(recurse)
                recurse = false;
            end
            
            if ~exist('editor','var') || isempty(editor)
                editor = true;
            end

            MBeautifier.FormattingPipeline.formatFiles(directory, fileFilter, recurse, editor);
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
end
