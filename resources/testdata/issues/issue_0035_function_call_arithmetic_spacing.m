% Targeted regression fixture for issue #35.
% These examples must remain stable when formatted with the default
% configuration, even though matrix indexing arithmetic padding is disabled.

% #35, if ArithmeticOperatorPadding=0
trace(3 + 4)
a = eye(1 + 1)
