classdef TestDesktopAdapter < matlab.unittest.TestCase
    %TESTDESKTOPADAPTER Coverage for editor integration adapter layers.

    methods (Test)
        function testNewDocumentInitializesTextAtomically(testCase)
            text = sprintf('x = 1;\n');

            document = MBeautifier.DesktopAdapter.newDocument(text);
            testCase.addTeardown(@() TestDesktopAdapter.closeIfValid(document));

            testCase.verifyEqual(MBeautifier.DesktopAdapter.getText(document), text);
        end

        function testDesktopAdapterCanReadWriteDocumentState(testCase)
            path = FormatterTestUtils.writeTempTextFile('desktopAdapterFixture.m', sprintf('x = 1;\n'));
            document = MBeautifier.DesktopAdapter.openDocument(path);
            testCase.addTeardown(@() TestDesktopAdapter.closeIfValid(document));

            MBeautifier.DesktopAdapter.activateDocument(document);
            MBeautifier.DesktopAdapter.setSelection(document, [1, 1, 1, Inf]);

            testCase.verifyEqual(MBeautifier.DesktopAdapter.getFilename(document), path);
            testCase.verifyEqual(MBeautifier.DesktopAdapter.getSelectedText(document), 'x = 1;');

            MBeautifier.DesktopAdapter.setText(document, sprintf('x = 2;\n'));
            testCase.verifyEqual(MBeautifier.DesktopAdapter.getText(document), sprintf('x = 2;\n'));
        end

    end

    methods (Static, Access = private)
        function closeIfValid(document)
            if ~isempty(document) && isvalid(document)
                document.close();
                drawnow();
            end
        end
    end
end
