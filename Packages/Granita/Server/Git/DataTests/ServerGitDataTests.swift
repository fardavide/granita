// Tests for ServerGitData. The argument vector for each subcommand family is asserted as an
// array, not merely observed to succeed: --no-ext-diff and --no-color are not universal flags,
// and rev-parse accepts --no-color by emitting it as an output line.
