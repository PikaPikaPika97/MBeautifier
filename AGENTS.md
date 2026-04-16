# Agent Notes for MBeautifier

## Overview

MBeautifier is a MATLAB source formatter implemented in MATLAB itself. The public API lives in `MBeautify.m`, and the main formatting logic is split between token-level formatting in `+MBeautifier/MFormatter.m` and indentation in `+MBeautifier/MIndenter.m`.

The project is small and configuration-driven. Formatting behavior is primarily controlled by `resources/settings/MBeautyConfigurationRules.xml`, which is loaded through `+MBeautifier/+Configuration/Configuration.m`.

## Main Entry Points

- `MBeautify.m`: public static API for formatting editor pages, selections, single files, and batches of files.
- `MBeautyShortcuts.m`: creates MATLAB shortcuts / favorites that call the public API.
- `+MBeautifier/MFormatter.m`: performs token and line formatting, directive handling, comment splitting, newline normalization, operator padding, and continuation-line processing.
- `+MBeautifier/MIndenter.m`: applies indentation after formatting using keyword-based indentation rules.
- `resources/settings/MBeautyConfigurationRules.xml`: default formatter configuration.

## Package Structure

- `+MBeautifier/`: core formatter, indenter, directive handling, constants, and string memento helpers.
- `+MBeautifier/+Configuration/`: XML-backed configuration model for operator, keyword, and special rules.
- `resources/settings/`: formatter defaults in XML.
- `resources/testdata/`: sample MATLAB files used as regression-oriented reference inputs.

## Implementation Notes

- MATLAB package folders (`+MBeautifier`, `+Configuration`) are part of the namespace. Renames here are high impact.
- `MBeautify.formatFileNoEditor` formats with `fileread` / `fopen`, while `MBeautify.formatFile` and editor-related methods depend on `matlab.desktop.editor`.
- `MFormatter` is stateful during a run. It tracks block comments, directives, continuation lines, and configuration switches while iterating line-by-line.
- `MIndenter` uses keyword stacks and continuation tracking rather than a full parser. Small logic changes can have broad formatting side effects.
- Directive support is real project behavior, not documentation only. Avoid changes that accidentally break `% MBeautifierDirective:...` or `% MBD:...` handling.
- `DirectiveDirector` currently recognizes directives with a strict end-of-line regex and mainly routes the `Format` directive on/off behavior.
- `MBeautify.getConfiguration()` caches the parsed configuration behind an MD5 checksum of `MBeautyConfigurationRules.xml`, so XML edits are expected to invalidate and reload the configuration.
- `MBeautify.indentPage(...)` is not a pure formatter step; it coordinates with MATLAB Editor indentation preferences and should be treated as side-effectful editor integration.
- Shortcut creation contains version-specific MATLAB UI integration, especially around the pre/post R2019b split in `MBeautyShortcuts.m`.
- Some historical spellings are part of the live implementation and XML schema, for example `KeyworPaddingRule`, `InlineContinousLines`, and `#MBeutyString#`. Do not "clean them up" casually without tracing all usages.

## Validation

There is no formal automated `matlab.unittest` suite in the repository at the moment.

Use these checks after formatter changes:

1. Review `resources/testdata/testfile.m`. The header states it should not change when run through the formatter.
2. Review `resources/testdata/testfile_bugs.m` for known edge cases that are not yet merged into the main reference file.
3. In MATLAB, smoke test the public APIs that match your change:
   - `MBeautify.formatCurrentEditorPage()`
   - `MBeautify.formatEditorSelection()`
   - `MBeautify.formatFile(...)`
   - `MBeautify.formatFiles(...)`
4. If configuration behavior changed, verify the corresponding rule in `resources/settings/MBeautyConfigurationRules.xml`.
5. If the change touches directives, continuation lines, or indentation, run a targeted manual MATLAB smoke test instead of trusting string-level inspection alone.

## Editing Guidance

- Keep changes minimal and local. The formatter is mostly string-processing code with many edge cases.
- Preserve existing comments and add precise comments only where the logic is genuinely non-obvious.
- Prefer fixing root causes over adding fallbacks or silent degradation.
- Be careful with old MATLAB compatibility. The README says testing reaches back to MATLAB R2013b.
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
- `resources/testdata/testfile_bugs.m`
