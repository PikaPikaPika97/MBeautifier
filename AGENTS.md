# Agent Notes for MBeautifier

## Overview

MBeautifier is a MATLAB source formatter implemented in MATLAB itself. The public API lives in `MBeautify.m`, which now acts primarily as a facade over the headless formatting pipeline and the MATLAB desktop editor integration.

The project is small and configuration-driven. Formatting behavior is primarily controlled by `resources/settings/MBeautyConfigurationRules.xml`, which is loaded through `+MBeautifier/+Configuration/Configuration.m`.

## Main Entry Points

- `MBeautify.m`: public static facade for formatting editor pages, selections, single files, and batches of files.
- `MBeautyShortcuts.m`: creates MATLAB shortcuts / favorites that call the public API.
- `+MBeautifier/FormattingPipeline.m`: headless formatting pipeline, file-system validation, and shared formatter/indenter orchestration.
- `+MBeautifier/EditorApp.m`: MATLAB desktop editor integration, selection handling, document save/open flows, and preference-backed indentation coordination.
- `+MBeautifier/MFormatter.m`: performs token and line formatting, directive handling, comment splitting, newline normalization, operator padding, and continuation-line processing.
- `+MBeautifier/MIndenter.m`: applies indentation after formatting using keyword-based indentation rules.
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
- `MBeautify.formatText`, `MBeautify.formatFileNoEditor`, `MBeautify.formatFiles(..., false)`, `MBeautify.checkFile`, and `MBeautify.diffFile(s)` run through `FormattingPipeline`, while `MBeautify.formatFile` and editor-related methods depend on `EditorApp` and `matlab.desktop.editor`.
- `MFormatter` is stateful during a run. It tracks block comments, directives, continuation lines, and configuration switches while iterating line-by-line.
- `MIndenter` uses keyword stacks and continuation tracking rather than a full parser. Small logic changes can have broad formatting side effects.
- Directive support is real project behavior, not documentation only. Avoid changes that accidentally break `% MBeautifierDirective:...` or `% MBD:...` handling.
- `DirectiveDirector` currently recognizes directives with a strict end-of-line regex and mainly routes the `Format` directive on/off behavior.
- `ConfigurationResolver` owns configuration resolution. It supports explicit configuration injection, project-local `.mbeautifier.xml` discovery, and caching of the default XML configuration behind an MD5 checksum of `MBeautyConfigurationRules.xml`.
- `EditorApp.indentPage(...)` is not a pure formatter step; it coordinates with MATLAB Editor indentation preferences and should be treated as side-effectful editor integration.
- `FormattingPipeline.requireExistingDirectory(...)` is the directory validation boundary for batch formatting. Keep batch input validation there instead of re-spreading it through `MBeautify`.
- Shortcut creation contains version-specific MATLAB UI integration, especially around the pre/post R2019b split in `MBeautyShortcuts.m`.
- Desktop integration currently still depends on `com.mathworks.services.Prefs` for indentation preference control. Treat that dependency as version-sensitive and keep it isolated.
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
6. If the change touches directives, continuation lines, or indentation, run a targeted manual MATLAB smoke test instead of trusting string-level inspection alone.
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
- `+MBeautifier/Constants.m`
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
- `tests/TestBatchFormatting.m`
- `tests/TestBatchCheckMode.m`
- `tests/TestProjectConfigurationDiscovery.m`
