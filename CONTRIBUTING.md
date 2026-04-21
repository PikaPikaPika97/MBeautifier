Feel free to contribute in case of new bugs found. 
In the pull request please provide:
 - the description of the problem
 - a minimal example that can reproduce the issue
 - Matlab version you experienced the issue on
 - the output of `tests/run_all_tests` after your change
 
 For existing and usassigned bugs, please assign the issue to yourself before starting to work on it.
 
 For formatter changes, please update any affected XML configuration
 rules, regression fixtures under `resources/testdata/`, and the
 corresponding `matlab.unittest` coverage under `tests/`.

Maintenance regression workflow
-------------------------------

For formatter or indenter bug fixes, add or extend a regression test before
changing implementation. Prefer cross-behavior coverage over a one-case
assertion: include nearby configuration switches, directives, string/comment
and transpose boundaries, continuation behavior, and idempotence when they can
interact with the bug. Do not skip a failing test, mock successful formatting,
swallow errors, or add silent fallback behavior to make a gate pass.

Recommended gates before a phase or pull request is accepted:
 - run the focused `matlab.unittest` class or classes for the touched subsystem
 - run `tests/run_all_tests`
 - run `check_matlab_code` on changed MATLAB files
 - run `tests/run_performance_baseline` when formatter or indenter throughput
   could be affected

Internal boundaries for future changes:
 - `+MBeautifier/SourceLine.m` is the line-level lexical analysis entry point.
   Formatter and indenter code should reuse it for string/comment views,
   continuation tokens, container depth deltas, and leading closing-container
   counts.
 - `+MBeautifier/+Configuration/Configuration.m` owns typed access to
   configuration semantics. Formatter and indenter code should use those
   accessors instead of direct `specialRule('...')` string lookups.
 - `+MBeautifier/ContainerScanner.m` owns bracket depth only, while
   `+MBeautifier/ContainerFormatting.m` owns matrix, cell, indexing, and
   function-call container formatting decisions. Container-related bug fixes
   should first extend `tests/TestContainerFormattingMatrix.m`.
 - Public `MBeautify.*` APIs and XML configuration keys should remain
   compatible unless a breaking change has been agreed in advance.

 For new changes and features, please make an issue without starting the
 implementation, to make us able to discuss the validness and the
 side-effect less feasibility of the change or new feature in advance.
 
