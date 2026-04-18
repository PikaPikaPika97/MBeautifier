function baseline = run_performance_baseline()
%RUN_PERFORMANCE_BASELINE Run lightweight, opt-in formatter timing checks.

testRoot = fileparts(mfilename('fullpath'));
repoRoot = fileparts(testRoot);
helperRoot = fullfile(testRoot, 'helpers');

addpath(repoRoot);
addpath(helperRoot);

cleanupRepo = onCleanup(@() rmpath(repoRoot)); %#ok<NASGU>
cleanupHelpers = onCleanup(@() rmpath(helperRoot)); %#ok<NASGU>

fixtures = { ...
    struct('name', 'testfile', 'text', FormatterTestUtils.readFixture('testfile.m'), 'threshold', 5.0), ...
    struct('name', 'issue_0035', 'text', FormatterTestUtils.readFixture(fullfile('issues', ...
        'issue_0035_function_call_arithmetic_spacing.m')), 'threshold', 2.0), ...
    struct('name', 'statement_break_context_aware', 'text', sprintf('clc; clear; close all;\n'), 'threshold', 1.0, ...
        'overrides', struct('StatementBreakStrategy', 'ContextAware')) ...
    };

rows = cell(numel(fixtures), 3);
for idx = 1:numel(fixtures)
    fixture = fixtures{idx};
    if ~isfield(fixture, 'overrides')
        fixture.overrides = struct();
    end

    tic;
    for runIdx = 1:3
        FormatterTestUtils.formatText(fixture.text, fixture.overrides); %#ok<NASGU>
    end
    elapsed = toc / 3;

    rows(idx, :) = {fixture.name, elapsed, fixture.threshold};
    if elapsed > fixture.threshold
        error('tests:run_performance_baseline:SlowFixture', ...
            'Fixture "%s" exceeded the %.2fs baseline with %.2fs.', ...
            fixture.name, fixture.threshold, elapsed);
    end
end

baseline = cell2table(rows, 'VariableNames', {'Fixture', 'SecondsPerRun', 'ThresholdSeconds'});
disp(baseline);
end
