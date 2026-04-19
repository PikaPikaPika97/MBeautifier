# Agent Notes for MBeautifier

## Overview

MBeautifier is a MATLAB source formatter implemented in MATLAB itself. The public API lives in `MBeautify.m`, which acts as a thin facade over the headless formatting pipeline and the MATLAB desktop editor integration.

The project is small and configuration-driven. Formatting behavior is primarily controlled by `resources/settings/MBeautyConfigurationRules.xml`, which is loaded through `+MBeautifier/+Configuration/Configuration.m`.

## Main Entry Points

- `MBeautify.m`: public static facade for formatting text, editor pages, selections, single files, and batches of files.
- `MBeautyShortcuts.m`: returns an explicit unsupported-shortcut error with manual Favorite commands.
- `+MBeautifier/FormattingPipeline.m`: headless formatting pipeline, file-system validation, and shared formatter/indenter orchestration.
- `+MBeautifier/EditorApp.m`: MATLAB desktop editor integration, selection handling, document save/open flows, and editor text normalization.
- `+MBeautifier/DesktopAdapter.m`: narrow wrapper around `matlab.desktop.editor` document operations.
- `+MBeautifier/MFormatter.m`: performs token and line formatting, directive handling, comment splitting, newline normalization, operator padding, and continuation-line processing.
- `+MBeautifier/MIndenter.m`: facade for indentation after formatting.
- `+MBeautifier/BlockIndentationEngine.m`: applies keyword-stack and continuation indentation rules.
- `+MBeautifier/SourceLine.m`: performs one-line lexical source analysis for code/comment/string boundaries.
- `+MBeautifier/LineFormattingStages.m`: contains focused single-line formatting transformations.
- `+MBeautifier/ContainerScanner.m`: calculates container bracket depths.
- `+MBeautifier/ContinuationFormatting.m`: contains helpers for continued source lines.
- `resources/settings/MBeautyConfigurationRules.xml`: default formatter configuration.
- `tests/run_all_tests.m`: stable entry point for the `matlab.unittest` suite, including headless and desktop smoke coverage.

## Package Structure

- `+MBeautifier/`: facade helpers, core formatter, indenter, directive handling, constants, and string memento helpers.
- `+MBeautifier/+Configuration/`: XML-backed configuration model for operator, keyword, and special rules.
- `resources/settings/`: formatter defaults in XML.
- `resources/testdata/`: sample MATLAB files used as regression-oriented reference inputs.
- `tests/`: class-based regression and focused behavior coverage for the formatter pipeline.

## Implementation Notes

- MATLAB package folders (`+MBeautifier`, `+Configuration`) are part of the namespace. Renames here are high impact.
- `MBeautify` should stay thin. Headless work belongs in `FormattingPipeline`, and desktop/editor work belongs in `EditorApp`.
- `MBeautify.formatText`, `MBeautify.formatFile`, `MBeautify.formatFileNoEditor`, `MBeautify.formatFiles(..., false)`, `MBeautify.checkFile`, and `MBeautify.diffFile(s)` run through `FormattingPipeline`, while editor-specific methods depend on `EditorApp` and `matlab.desktop.editor`.
- `MFormatter` is stateful during a run. It tracks block comments, directives, continuation lines, and configuration switches while iterating line-by-line.
- `MIndenter` delegates to `BlockIndentationEngine`, which uses keyword stacks and continuation tracking rather than a full parser. Small logic changes can have broad formatting side effects.
- `SourceLine`, `LineFormattingStages`, `ContainerScanner`, and `ContinuationFormatting` are extraction boundaries from `MFormatter`; prefer adding focused behavior there when the boundary already matches the change.
- Directive support is real project behavior, not documentation only. Avoid changes that accidentally break `% MBeautifierDirective:...` or `% MBD:...` handling.
- `DirectiveDirector` currently recognizes directives with a strict end-of-line regex and mainly routes the `Format` directive on/off behavior.
- `ConfigurationResolver` owns configuration resolution. It supports explicit configuration injection, project-local `.mbeautifier.xml` discovery, and caching of the default XML configuration behind an MD5 checksum of `MBeautyConfigurationRules.xml`.
- `EditorApp.indentPage(...)` is editor text normalization after the headless formatter. It does not call MATLAB Smart Indent and does not mutate MATLAB preferences.
- `FormattingPipeline.requireExistingDirectory(...)` is the directory validation boundary for batch formatting. Keep batch input validation there instead of re-spreading it through `MBeautify`.
- Automatic shortcut creation is intentionally unsupported. `MBeautyShortcuts.createShortcut(...)` should keep raising `MBeautifier:ShortcutNotSupported` with manual Favorite guidance.
- Desktop integration currently depends on `matlab.desktop.editor`. Treat that dependency as version-sensitive and keep it isolated behind `DesktopAdapter`.
- Some historical spellings are part of the live implementation and XML schema, for example `KeyworPaddingRule`, `InlineContinousLines`, and `#MBeutyString#`. Do not "clean them up" casually without tracing all usages.
- Modern formatting behavior is now configurable through `StatementBreakStrategy`, `DeclarationSpacingStyle`, and `InlineCommentSpacingStrategy`. The legacy XML keys still load, but the newer strategy keys take precedence when both are present.

## Validation

Use these checks after formatter changes:

1. Run `tests/run_all_tests`. This is the primary automated regression gate for the formatter pipeline and desktop smoke flows.
2. Review `resources/testdata/testfile.m`. It is the canonical golden fixture for default formatting behavior and should remain stable after the test suite passes.
3. Review `resources/testdata/issues/issue_0035_function_call_arithmetic_spacing.m` for the targeted regression fixture covering issue `#35`.
4. In MATLAB, smoke test the public APIs that match your change:
   - `MBeautify.formatText(...)`
   - `MBeautify.formatCurrentEditorPage()`
   - `MBeautify.formatEditorSelection()`
    - `MBeautify.formatFile(...)`
    - `MBeautify.formatFiles(...)`
   - `MBeautify.checkFile(...)` / `MBeautify.diffFile(...)`
5. If configuration behavior changed, verify the corresponding rule in `resources/settings/MBeautyConfigurationRules.xml` and, when relevant, `.mbeautifier.xml` project overrides.
6. If the change touches directives, continuation lines, syntax boundary handling, or indentation, run focused MATLAB tests in addition to string-level inspection.
7. If the change touches batch formatting or facade routing, review `tests/TestBatchFormatting.m`, `tests/TestBatchCheckMode.m`, and `tests/TestIndentationRules.m` for the expected focused coverage before adding new tests.
8. Run `tests/run_performance_baseline` when the change could plausibly affect formatter throughput.

## Editing Guidance

- Keep changes minimal and local. The formatter is mostly string-processing code with many edge cases.
- Preserve existing comments and add precise comments only where the logic is genuinely non-obvious.
- Prefer fixing root causes over adding fallbacks or silent degradation.
- Be careful with MATLAB compatibility boundaries. Recent releases are continuously validated; older releases may still work, especially in headless mode, but are no longer continuously tested.
- When touching spacing, continuation lines, comments, or directives, assume regressions can appear outside the immediate case you changed.

## Files Reviewed for This Note

- `README.md`
- `CONTRIBUTING.md`
- `MBeautify.m`
- `MBeautyShortcuts.m`
- `+MBeautifier/MFormatter.m`
- `+MBeautifier/MIndenter.m`
- `+MBeautifier/BlockIndentationEngine.m`
- `+MBeautifier/Constants.m`
- `+MBeautifier/ContainerScanner.m`
- `+MBeautifier/ContinuationFormatting.m`
- `+MBeautifier/EditorApp.m`
- `+MBeautifier/FormattingPipeline.m`
- `+MBeautifier/LineFormattingStages.m`
- `+MBeautifier/SourceLine.m`
- `+MBeautifier/DirectiveDirector.m`
- `+MBeautifier/+Configuration/Configuration.m`
- `resources/settings/MBeautyConfigurationRules.xml`
- `resources/testdata/testfile.m`
- `resources/testdata/issues/issue_0035_function_call_arithmetic_spacing.m`
- `tests/run_all_tests.m`
- `tests/run_performance_baseline.m`
- `tests/TestFormatterRegression.m`
- `tests/TestModernFormatting.m`
- `tests/TestIndentationRules.m`
- `tests/TestSourceLineModel.m`
- `tests/TestLineFormattingStages.m`
- `tests/TestContainerAndContinuationFormatting.m`
- `tests/TestSyntaxPreservation.m`
- `tests/TestBatchFormatting.m`
- `tests/TestBatchCheckMode.m`
- `tests/TestProjectConfigurationDiscovery.m`
