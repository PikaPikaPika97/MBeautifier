classdef DesktopAdapter
    %DESKTOPADAPTER Wrap version-sensitive MATLAB Editor document operations.

    methods (Static)
        function document = getActiveDocument()
            document = matlab.desktop.editor.getActive();
        end

        function tf = isDocumentOpen(file)
            tf = matlab.desktop.editor.isOpen(file);
        end

        function document = openDocument(file)
            document = matlab.desktop.editor.openDocument(file);
        end

        function document = newDocument(text)
            document = matlab.desktop.editor.newDocument();
            try
                document.Text = text;
            catch ME
                MBeautifier.DesktopAdapter.closeDocument(document);
                rethrow(ME);
            end
        end

        function closeDocument(document)
            document.close();
        end

        function saveDocumentAs(document, file)
            document.saveAs(file);
        end

        function activateDocument(document)
            document.makeActive();
        end

        function smartIndentContents(document)
            document.smartIndentContents();
        end

        function text = getText(document)
            text = document.Text;
        end

        function setText(document, text)
            document.Text = text;
        end

        function selection = getSelection(document)
            selection = document.Selection;
        end

        function setSelection(document, selection)
            document.Selection = selection;
        end

        function text = getSelectedText(document)
            text = document.SelectedText;
        end

        function goToPositionInLine(document, line, column)
            document.goToPositionInLine(line, column);
        end

        function fileName = getFilename(document)
            fileName = document.Filename;
        end
    end
end
