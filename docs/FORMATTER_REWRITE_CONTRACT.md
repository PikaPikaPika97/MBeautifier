# Formatter Rewrite Contract

This document defines the implementation contract for the staged MBeautifier
rewrite. It is intentionally concrete so each phase can be accepted with tests
and committed independently.

## Goals

- Keep the formatter small at each boundary: public facade, headless pipeline,
  formatter stages, indentation, and desktop integration.
- Make the headless pipeline the primary product path for automation and CI.
- Define the default style from the MATLAB Coding Guidelines, with project
  rules documented as explicit deviations.
- Prefer explicit failures over fallback behavior. Invalid configuration,
  unknown options, unsupported desktop integration, or malformed inputs must
  raise errors with actionable messages.
- Avoid experimental product dependencies in the core formatter. In particular,
  `mtree` can be used for manual diagnostics, but not in runtime formatting or
  test gate logic.

## Default Formatting Contract

- Indentation uses four spaces per level.
- Public API examples should prefer modern MATLAB name-value syntax.
- Binary assignment, relational, and logical operators have one space on both
  sides.
- Name-value assignment keeps no spaces around `=`.
- Element-wise arithmetic operators follow the MATLAB Coding Guidelines unless
  a documented project rule overrides the guideline.
- Inline comments are separated from code by one space in normalized mode.
- `arguments` blocks are formatted as first-class syntax, not as ordinary
  keyword text.
- Continuation lines preserve MATLAB syntax first; visual alignment is
  secondary to stable, idempotent output.
- Directives remain supported and must have regression coverage.

## Public Interface Contract

- `MBeautify.formatText` is the canonical text-formatting API.
- `MBeautify.formatFile` is the canonical headless file-formatting API.
- Batch, check, and diff APIs use the same headless pipeline by default.
- MATLAB Editor operations remain available only through editor-specific entry
  points such as `formatCurrentEditorPage` and `formatEditorSelection`.
- Deprecated compatibility entry points may be removed in this rewrite, but
  removals must be reflected in tests and README examples in the same phase.

## Module Contract

- Lexing/source modeling owns string, comment, directive, operator, bracket, and
  continuation token recognition.
- Formatting stages own isolated transformations: statement splitting,
  declaration spacing, operator spacing, keyword spacing, and inline comment
  spacing.
- `ContainerScanner` owns bracket depth only; it must not decide formatting,
  indexing, or function-call semantics.
- `ContainerFormatting` owns matrix, cell, indexing, and function-call
  container formatting decisions.
- `MFormatter` owns line-level formatting orchestration and should delegate
  container heuristics to `ContainerFormatting`.
- Indentation owns block state and continuation indentation after formatting.
- `DesktopAdapter` is the only runtime boundary around `matlab.desktop.editor`.
- `EditorApp` owns MATLAB Editor workflow orchestration only; it should not grow
  new selection-scanning, document-rebuild, or formatting-rule branches.
- `EditorSelectionFormatting` owns selection expansion and document text
  rebuild planning for `formatEditorSelection`.

## Acceptance Gates

Each phase must pass the following before its commit:

1. `tests/run_all_tests`
2. Targeted tests for the changed subsystem
3. `tests/run_performance_baseline` when formatter throughput can change
4. `git diff` review confirming the phase did not include unrelated changes
5. `git status --short` showing only intentional files before commit

Editor changes should also run the focused desktop tests:
`tests/TestDesktopAdapter.m`, `tests/TestEditorIntegrationState.m`,
`tests/TestEditorBehaviorMatrix.m`, and `tests/TestEditorSelectionFormatting.m`.
Do not accept skipped Editor failures, mocked successful formatting, or swallowed
desktop API errors as the default workflow.

## Commit Protocol

Use one Conventional Commit per completed phase. The commit body should state:

- phase goal
- public API or formatting behavior changes
- tests run
- fixture updates, if any
- known follow-up work, if any
