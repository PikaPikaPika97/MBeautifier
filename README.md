# MBeautifier

MBeautifier is a lightweight M-Script based MATLAB source code formatter. It can run headlessly for automation and CI, and it can also format the current MATLAB Editor page or selection.

![Basic working](https://cloud.githubusercontent.com/assets/12681120/20592407/904cb1d6-b22d-11e6-93dd-1637c3738e50.png)


Main features
-------------
 - Padding operators and keywords with white spaces
 - Configurable indentation character, indentation level, and function indentation strategy
 - Removal/addition of continuous empty lines
 - Inserting missing element separators (commas) in matrix and cell array initializations
 - Inserting missing continuation symbols in matrix and cell array initializations
 - In-lining continuous lines
 - Formatting plain text, one file, batches of files, the current MATLAB Editor page, or the current MATLAB Editor selection
 - Structured `check` and `diff` APIs for automation without rewriting files
 - Project-local `.mbeautifier.xml` configuration discovery
 - XML-driven formatting rules with explicit per-call configuration overrides

Deployment and Configuration
----------------------------
Simply add the root directory to the MATLAB path.

### Configuration

The configuration can be modified by editing the `MBeautifier\resources\settings\MBeautyConfigurationRules.xml` file.

#### Configuration rules

Currently three types of configuration rules are implemented: `Operator padding rule`, `Keyword padding rule` and `Special rule`.

#### Operator padding rules

Each `OperatorPaddingRule` represents the formatting rules for one single operator and consists of a key, the string that should be replaced and a string that should be used for the replacement.

    <OperatorPaddingRule>
        <Key>NotEquals</Key>
        <ValueFrom>~=</ValueFrom>
        <ValueTo> ~= </ValueTo>
    </OperatorPaddingRule>
	
The example above shows the rule for the "not equals" operator. The `ValueFrom` node stores the operator `~=` and the `ValueTo` node stores the expected format: the operator should be preceded and followed by a white-space character.

#### Keyword padding rules

Each `KeyworPaddingRule` represents the formatting rules for one single keyword and consists the keyword itself, and a numeric value of the needed white-space padding on the right side.

	<KeyworPaddingRule>
		<Keyword>properties</Keyword>
		<RightPadding>1</RightPadding>
	</KeyworPaddingRule>
	
The example above shows the rule for the keyword "properties". The `RightPadding` node stores the expected right padding white space amount: the keyword should be preceded by one white space character.

> Note: Not all of the keywords are listed - only the ones where controlling padding makes sense.

#### Special rules

These rules are basically switches for certain functionalities of MBeautifier.

The current list of special rules:

##### Special rules regarding new lines
 - **MaximalNewLines**: Integer value. MBeautifier will remove continuous empty lines. This rule can be used to specify the maximal number of maximal continuous empty lines.
 - **SectionPrecedingNewlineCount**: Integer value. Defines how many empty lines should precede the section comments (`%% `). Negative values mean no special formatting is needed (the final format is defined by the input and the MaximalNewLines rule). For any number "X" bigger or equal to zero: section comments will be preceded exactly by X empty lines.
 - **SectionTrailingNewlineCount**: Integer value. Defines how many empty lines should follow the section comments (`%% `). Negative values mean no special formatting is needed (the final format is defined by the input and the MaximalNewLines rule). For any number "X" bigger or equal to zero: section comments will be followed exactly by X empty lines.
 - **EndingNewlineCount**: Integer value. Defines how many empty lines should be placed on the end of the input. Negative values mean no special formatting is needed (the final format is defined by the input and the MaximalNewLines rule). For any number "X" bigger or equal to zero: input will trailed exactly by X empty lines.
 - **StatementBreakStrategy**: ['Always'|'ContextAware'|'Never']. Controls how MBeautifier handles multiple statements on a single line. `Always` always splits, `Never` preserves them, and `ContextAware` preserves compact guards such as `if cond; return; end` while still splitting setup chains such as `clc; clear; close all;`. Defaults to `"Never"`.
 - **DeclarationSpacingStyle**: ['Readable'|'Compact'|'Preserve']. Controls spacing inside declaration-heavy contexts such as `arguments` blocks. `Readable` keeps declarations explicit, `Compact` removes optional declaration spacing, and `Preserve` keeps intra-line spacing as-is. Defaults to `"Preserve"`.
 - **InlineCommentSpacingStrategy**: ['Normalize'|'Preserve']. Controls spacing before inline trailing comments. `Normalize` enforces a single separating space, `Preserve` keeps the original spacing. Defaults to `"Preserve"`.
 - **AllowMultipleStatementsPerLine**: [1|0]. Legacy alias for the statement break behavior. `0` maps to `StatementBreakStrategy = Always` and `1` maps to `StatementBreakStrategy = Never`.
 - **PreserveInlineCommentSpacing**: [1|0]. Legacy alias for the inline comment spacing behavior. `0` maps to `InlineCommentSpacingStrategy = Normalize` and `1` maps to `InlineCommentSpacingStrategy = Preserve`.
 
##### Special rules regarding matrix and cell array separators
 
 - **AddCommasToMatrices**: [1|0]. Indicates whether the missing element separator commas in matrices should be inserted. For example: `[1 2 3]` will be formatted as `[1, 2, 3]`.
 - **AddCommasToCellArrays**: [1|0]. Indicates whether the missing element separator commas in cell arrays should be inserted. For example: `{1 2 3}` will be formatted as `{1, 2, 3}`.
 
##### Special rules arithmetic operators 

 - **MatrixIndexing_ArithmeticOperatorPadding**: [1|0]. Indicates whether the arithmetic operators should be padded by white spaces (using the operator padding rules), when they are used to index matrices. For example: `matrix(end+1) = 1` can be formatted as `matrix(end+1) = 1` when value is set to 0, or as `matrix(end + 1) = 1` if value is set to 1.
 - **CellArrayIndexing_ArithmeticOperatorPadding**: [1|0]. Indicates the same as `MatrixIndexing_ArithmeticOperatorPadding` but for cell arrays.
 - **PreserveIndexExpressionSpacing**: [1|0]. When set to 1, MBeautifier preserves arithmetic spacing inside matrix and cell indexing expressions instead of applying the indexing padding rules. Set this to 0 to use `MatrixIndexing_ArithmeticOperatorPadding` and `CellArrayIndexing_ArithmeticOperatorPadding`. Defaults to 1.
 
##### Special rules regarding continous lines

 - **InlineContinousLines**: [1|0]. If set to 1, MBeautifier will in-line continuous line operators ("...") everywhere except in matrices (inside [] brackets) and in curly brackets ({}) - these cases are handled by the next two options. In-lining means: the "..." operator will be removed and the next line will be copied into its place.
 - **InlineContinousLinesInMatrixes**: [1|0]. Same as **InlineContinousLines**, but only has effect inside brackets ("[]").
 - **InlineContinousLinesInCurlyBracket**: [1|0]. Same as **InlineContinousLines**, but only has effect inside curly brackets ("{}").
 - **AutoAppendContinuationMarkers**: [1|0]. If set to 1, MBeautifier appends `...` while formatting multiline containers. Defaults to 0 so legal multiline matrix and cell literals are preserved without synthetic continuation markers.
 
##### Special rules regarding indentation

 - **IndentationCharacter**: [white-space|tab]. Specifies which character should be used for auto-indentation: white space or tabulator. Defaults to "white-space".
 - **IndentationCount**: Integer value. Specifies the level of auto-indentation (how many **IndentationCharacter** means one level of indentation). Defaults to "4".
 - **Indentation_TrimBlankLines**: [1|0]. Specifies if blank lines (lines containing only white space characters - as result of auto-indentation) should be trimmed (made empty) by MBeautifier. Defaults to "1" as it can lead to smaller file sizes.
 - **Indentation_Strategy**: ['AllFunctions'|'NestedFunctions'|'NoIndent']. Controls MBeautifier's keyword-stack indentation mode for function bodies. Possible values: "AllFunctions" - indent the body of each function, "NestedFunctions" - indent the body of nested functions only, "NoIndent" - all of the functions' body will be indented the same amount as the function keyword itself.
  
#### Directives

MBeautifier directives are special constructs which can be used in the source code to control MBeautifier during the formatting process. The example below controls the directive named `Format` and sets its value to `on` and then later to `off`.

    a =  1;
    % MBeautifierDirective:Format:Off
    longVariableName = 'where the assigement is';
    aligned          = 'with the next assignment';
    % MBD:Format:On
    someMatrix  =  [1 2 3];
    
The standard format of a directive line is:
 - following the pattern: `<ws>%<ws>MBeautifierDirective<ws>:<ws>:NAME<ws>:<ws>VALUE<ws>[NEWLINE]` or : `<ws>%<ws>MBD<ws>:<ws>:NAME<ws>:<ws>VALUE<ws>[NEWLINE]`where
    -   `<ws>` means zero or more optional white space characters
    -   `NAME` means the directive name (only latin letters, case insensitive)
    -   `VALUE` means the directive value (only latin letters, case insensitive)
 - must not contain any code or any trailing comment  (only the directive comment above)
 - must not be inside a block comment
 - must not be inside any line continousment
 - the keyword `MBeautifierDirective` is freely interchangable with `MBD`

> **Note: Directive names which are not present in the list below, or directive values which are not applicable to the specified directive will be ignored together with a MATLAB warning**.

##### Directive List

###### `Format`
Directive to generally control the formatting process.
Possible values:
- `on` - Enable formatting
- `off` - Disable formatting

Example:
In the code-snippet below MBeautifier is formatting the first line using the configuration currently active, but will not format the lines 2,3,4,5. The last line will be beautified again using the current configuration.

    a =  1;
    % MBeautifierDirective:Format:Off
    longVariableName = 'where the assigement is';
    aligned          = 'with the next assignment';
    % MBeautifierDirective:Format:On
    someMatrix  =  [1 2 3];
    
The formatted code will look like (configuration dependently):

	a = 1;
	% MBeautifierDirective:Format:Off
	longVariableName = 'where the assigement is';
	aligned          = 'with the next assignment';
	% MBeautifierDirective:Format:On
	someMatrix = [1, 2, 3];

Usage
-----

### From MATLAB Command Window

The main public entry points are:

 - Perform formatting on the currently active page of MATLAB Editor. Command: `MBeautify.formatCurrentEditorPage()`. By default the file is not saved, but it remains opened modified in the editor. Optionally the formatted file can be saved using the `MBeautify.formatCurrentEditorPage(true)` syntax.
 - Perform formatting on the currently selected text of the active page of MATLAB Editor. Command: `MBeautify.formatEditorSelection()`. An optional saving mechanism as above exists also in this case. Useful in case of large files, but in any case `MBeautify.formatCurrentEditorPage()` is suggested.
 - Perform formatting on plain text. Command: `MBeautify.formatText(text)`. Use `MBeautify.formatText(text, 'Configuration', cfg)` or `MBeautify.formatText(text, 'ConfigurationFile', xmlFile)` to override the resolved configuration for a single call.
 - Perform headless formatting on a file. Command: `MBeautify.formatFile(file)`. Can be used with one argument for in-place formatting or two arguments as `MBeautify.formatFile(file, outFile)`. Output can be the same as input.
 - Use the legacy alias `MBeautify.formatFileNoEditor(file)` or `MBeautify.formatFileNoEditor(file, outFile)` only for existing automation that has not migrated yet.
 - Perform headless formatting on several files in a directory. Command: `MBeautify.formatFiles(directory, fileFilter)`. The first argument is an absolute path to a directory, the second one is a wildcard expression (used for `dir` command) to filter files in the target directory. The files will be formatted in-place (overwritten).
 - Inspect file(s) without rewriting them. Commands: `MBeautify.checkFile(file)`, `MBeautify.diffFile(file)`, `MBeautify.checkFiles(directory, fileFilter, recurse, editor)`, and `MBeautify.diffFiles(...)`. These return structured summaries that can be consumed by automation or CI.
 
### Shortcuts
 
 Automatic shortcut creation is no longer supported. Create a Favorite manually and, if desired, pin it to the Quick Access Toolbar. Use one of these commands as the Favorite code:

  - `addpath('C:\path\to\MBeautifier'); MBeautify.formatCurrentEditorPage();`
  - `addpath('C:\path\to\MBeautifier'); MBeautify.formatEditorSelection();`
  - `addpath('C:\path\to\MBeautifier'); [sourceFile, sourcePath] = uigetfile(); drawnow(); if isequal(sourceFile, 0) || isequal(sourcePath, 0), return; end; sourceFile = fullfile(sourcePath, sourceFile); [destFile, destPath] = uiputfile(); drawnow(); if isequal(destFile, 0) || isequal(destPath, 0), return; end; destFile = fullfile(destPath, destFile); MBeautify.formatFile(sourceFile, destFile);`
 
The Favorite commands add the MBeautifier root directory to the MATLAB path too, therefore no MATLAB path preparation is needed to use MBeautifier next time when a new MATLAB instance is opened.

### Desktop Integration

`MBeautify.formatCurrentEditorPage` and `MBeautify.formatEditorSelection` depend on the MATLAB desktop editor integration.

`MBeautify.formatText`, `MBeautify.formatFile`, `MBeautify.formatFileNoEditor`, `MBeautify.formatFiles`, `MBeautify.checkFile`, `MBeautify.diffFile`, `MBeautify.checkFiles`, and `MBeautify.diffFiles` run through the headless formatting pipeline and are the preferred entry points for automation.

MBeautifier currently uses `matlab.desktop.editor` for desktop integration. This is a version-sensitive dependency and should be treated as the main compatibility boundary for future MATLAB desktop releases.

### Internal Architecture

`MBeautify.m` is the public facade. It parses public arguments and delegates work to focused implementation modules.

Headless formatting, batch orchestration, check/diff inspection, file-system validation, and final file writes are routed through `+MBeautifier/FormattingPipeline.m`. MATLAB desktop editor integration is isolated in `+MBeautifier/EditorApp.m` and uses `+MBeautifier/DesktopAdapter.m` as the narrow wrapper around `matlab.desktop.editor`.

The core text transformation happens in `+MBeautifier/MFormatter.m`, then indentation is applied through `+MBeautifier/MIndenter.m` and `+MBeautifier/BlockIndentationEngine.m`. `MFormatter` is still the largest stateful component, but several focused helpers now own smaller boundaries:

 - `+MBeautifier/SourceLine.m`: separates code, comments, section separators, strings, transpose quotes, and block comments for one line.
 - `+MBeautifier/LineFormattingStages.m`: owns isolated single-line transformations such as inline comment spacing and `arguments` declaration spacing.
 - `+MBeautifier/ContainerScanner.m`: calculates bracket container depth for matrices, cell arrays, indexing, and function-call-like containers.
 - `+MBeautifier/ContinuationFormatting.m`: owns helper behavior for continued source lines.

Configuration loading remains XML-driven through `resources/settings/MBeautyConfigurationRules.xml`, but entry points can also accept an explicit configuration object or XML file path for one-off overrides.

Project-local configuration discovery is supported through a `.mbeautifier.xml` file. For file-based entry points, MBeautifier searches from the target file's directory upward and uses the nearest project configuration when no explicit configuration override is provided.

The main data flow is:

    MBeautify
      -> ConfigurationResolver
      -> FormattingPipeline
      -> MFormatter
      -> MIndenter / BlockIndentationEngine
      -> file write, editor update, or diff/check summary

### Tests

The repository includes a `matlab.unittest` suite under `tests/`.

Run the full suite from MATLAB with:

    tests/run_all_tests

Use `tests/run_all_tests` as the stable entry point so the helper paths under `tests/helpers` are configured correctly before the suite runs. The suite covers both the headless formatting pipeline and MATLAB desktop editor smoke flows. The regression fixtures live in `resources/testdata/`, with `testfile.m` acting as the canonical golden file and `resources/testdata/issues/issue_0035_function_call_arithmetic_spacing.m` tracking issue `#35`.

Focused coverage currently includes:

 - formatter regression fixtures and modern formatting rules
 - lexical source-line boundaries, string/comment splitting, and block comment tracking
 - line-formatting stages for inline comments and `arguments` declarations
 - container and continuation-line helpers
 - indentation-specific rules under `tests/TestIndentationRules.m`
 - batch formatting behavior under `tests/TestBatchFormatting.m`
 - structured `check` / `diff` inspection APIs and project-local configuration discovery
 - public API failure paths and desktop integration state handling
 - successful desktop formatting flows for editor pages, selections, and file-to-file formatting

For opt-in performance checks, run:

    tests/run_performance_baseline
 
Compatibility note
------------------

MBeautifier is currently validated against the recent MATLAB releases used for active development. Older MATLAB releases may still work, especially for the headless formatting pipeline, but they are no longer continuously tested in this repository.

Desktop integration has a narrower compatibility boundary than the headless pipeline because it depends on `matlab.desktop.editor`.

Planned future versions
-----------------------
 
It is planned that the project is maintained until MATLAB is shipped with a code formatter with a similar functionality.
 
It is planned to make MBeautifier also usable in Octave, by starting a new development branch using Java/Kotlin (versions 2.*). The MATLAB based branched will be developed in branch versions (1.*). 
 
