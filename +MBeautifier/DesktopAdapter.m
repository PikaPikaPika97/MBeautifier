classdef DesktopAdapter
    %DESKTOPADAPTER Wrap version-sensitive MATLAB Editor document operations.

    methods (Static)
        function document = getActiveDocument()
            document = matlab.desktop.editor.getActive();
        end

        function documents = getAllDocuments()
            documents = matlab.desktop.editor.getAll();
        end

        function tf = isDocumentOpen(file)
            tf = matlab.desktop.editor.isOpen(file);
        end

        function document = openDocument(file)
            MBeautifier.DesktopAdapter.flushEditorEvents();
            document = matlab.desktop.editor.openDocument(file);
            MBeautifier.DesktopAdapter.flushEditorEvents();
        end

        function document = newDocument(text)
            document = [];
            try
                [bootstrapDocument, bootstrapPath] = MBeautifier.DesktopAdapter.openBootstrapDocument();
                cleanupBootstrap = onCleanup( ...
                    @() MBeautifier.DesktopAdapter.closeBootstrapDocument(bootstrapDocument, bootstrapPath));
                MBeautifier.DesktopAdapter.flushEditorEvents();
                document = matlab.desktop.editor.newDocument();
                MBeautifier.DesktopAdapter.flushEditorEvents();
                MBeautifier.DesktopAdapter.setText(document, text);
                MBeautifier.DesktopAdapter.assertDocumentText(document, text);
            catch ME
                MBeautifier.DesktopAdapter.closeDocument(document);
                wrappedException = MException('MBeautifier:EditorDocumentCreationFailed', ...
                    'Unable to create a MATLAB Editor document with the requested text.');
                wrappedException = addCause(wrappedException, ME);
                throw(wrappedException);
            end
        end

        function closeDocument(document)
            if isempty(document) || ~isvalid(document)
                return;
            end

            document.close();
            MBeautifier.DesktopAdapter.flushEditorEvents();
        end

        function saveDocumentAs(document, file)
            document.saveAs(file);
            MBeautifier.DesktopAdapter.flushEditorEvents();
        end

        function activateDocument(document)
            document.makeActive();
            MBeautifier.DesktopAdapter.flushEditorEvents();
        end

        function smartIndentContents(document)
            document.smartIndentContents();
            MBeautifier.DesktopAdapter.flushEditorEvents();
        end

        function text = getText(document)
            text = document.Text;
        end

        function setText(document, text)
            document.Text = text;
            MBeautifier.DesktopAdapter.flushEditorEvents();
        end

        function selection = getSelection(document)
            selection = document.Selection;
        end

        function setSelection(document, selection)
            document.Selection = selection;
            MBeautifier.DesktopAdapter.flushEditorEvents();
        end

        function text = getSelectedText(document)
            text = document.SelectedText;
        end

        function goToPositionInLine(document, line, column)
            document.goToPositionInLine(line, column);
            MBeautifier.DesktopAdapter.flushEditorEvents();
        end

        function fileName = getFilename(document)
            fileName = document.Filename;
        end
    end

    methods (Static, Access = private)
        function [bootstrapDocument, bootstrapPath] = openBootstrapDocument()
            bootstrapPath = [tempname(), '.m'];
            MBeautifier.DesktopAdapter.writeBootstrapFile(bootstrapPath);

            try
                bootstrapDocument = matlab.desktop.editor.openDocument(bootstrapPath);
                MBeautifier.DesktopAdapter.flushEditorEvents();
            catch ME
                MBeautifier.DesktopAdapter.deleteFileIfPossible(bootstrapPath);
                rethrow(ME);
            end
        end

        function closeBootstrapDocument(document, path)
            MBeautifier.DesktopAdapter.closeDocument(document);
            MBeautifier.DesktopAdapter.deleteFileIfPossible(path);
        end

        function flushEditorEvents()
            drawnow();
            pause(0.05);
            drawnow();
        end

        function assertDocumentText(document, expectedText)
            if ~strcmp(document.Text, expectedText)
                error('MBeautifier:EditorDocumentTextMismatch', ...
                    'MATLAB Editor document text did not match the requested text after creation.');
            end
        end

        function writeBootstrapFile(path)
            fid = fopen(path, 'wt');
            if fid == -1
                error('MBeautifier:EditorBootstrapFileNotWritable', ...
                    'Unable to create temporary MATLAB Editor bootstrap file.');
            end

            fileCloser = onCleanup(@() fclose(fid));
            fprintf(fid, 'x = 1;\n');
        end

        function deleteFileIfPossible(path)
            if exist(path, 'file') == 2
                delete(path);
            end
        end
    end
end
