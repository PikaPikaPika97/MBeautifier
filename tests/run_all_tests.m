function results = run_all_tests()
%RUN_ALL_TESTS Run the repository MATLAB test suite.
%   results = run_all_tests() executes the class-based matlab.unittest
%   suite under tests/, prints a compact summary, and raises an error when
%   any test fails so the script can serve as a stable automation entry.

testRoot = fileparts(mfilename('fullpath'));
repoRoot = fileparts(testRoot);
helperRoot = fullfile(testRoot, 'helpers');

addpath(repoRoot);
addpath(helperRoot);

cleanupRepo = onCleanup(@() rmpath(repoRoot)); %#ok<NASGU>
cleanupHelpers = onCleanup(@() rmpath(helperRoot)); %#ok<NASGU>

fprintf('Running MATLAB tests from %s\n', testRoot);
results = runtests(testRoot, IncludeSubfolders = true);
disp(table(results));

failedMask = [results.Failed];
if any(failedMask)
    failedResults = results(failedMask);
    fprintf('Failed tests:\n');
    for idx = 1:numel(failedResults)
        fprintf('  %s\n', failedResults(idx).Name);
    end
    error('tests:run_all_tests:Failed', '%d MATLAB test(s) failed.', nnz(failedMask));
end

fprintf('All %d MATLAB test(s) passed.\n', numel(results));
end
