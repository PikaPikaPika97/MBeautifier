classdef EditorTestUtils
    %EDITORTESTUTILS Shared helpers for MATLAB Editor integration tests.

    methods (Static)
        function document = openTemporaryDocument(testCase, fileName, text)
            path = FormatterTestUtils.writeTempTextFile(fileName, text);
            document = MBeautifier.DesktopAdapter.openDocument(path);

            testCase.addTeardown(@() EditorTestUtils.closeIfValid(document));
            testCase.addTeardown(@() EditorTestUtils.deleteIfExists(path));
        end

        function document = newUnsavedDocument(testCase, text)
            openDocuments = MBeautifier.DesktopAdapter.getAllDocuments();
            testCase.addTeardown(@() EditorTestUtils.closeDocumentsOpenedAfter(openDocuments));
            document = MBeautifier.DesktopAdapter.newDocument(text);
            testCase.addTeardown(@() EditorTestUtils.closeIfValid(document));
        end

        function closeAllDocuments()
            documents = MBeautifier.DesktopAdapter.getAllDocuments();
            for idx = 1:numel(documents)
                EditorTestUtils.closeIfValid(documents(idx));
            end
        end

        function closeIfValid(document)
            MBeautifier.DesktopAdapter.closeDocument(document);
        end

        function closeDocumentsOpenedAfter(openDocuments)
            currentDocuments = MBeautifier.DesktopAdapter.getAllDocuments();
            for idx = 1:numel(currentDocuments)
                document = currentDocuments(idx);
                if EditorTestUtils.wasDocumentAlreadyOpen(document, openDocuments)
                    continue;
                end

                EditorTestUtils.closeIfValid(document);
            end
        end

        function deleteIfExists(path)
            if exist(path, 'file') == 2
                delete(path);
            end
        end
    end

    methods (Static, Access = private)
        function tf = wasDocumentAlreadyOpen(document, openDocuments)
            tf = false;
            for idx = 1:numel(openDocuments)
                if isvalid(openDocuments(idx)) && isequal(document, openDocuments(idx))
                    tf = true;
                    return;
                end
            end
        end
    end
end
