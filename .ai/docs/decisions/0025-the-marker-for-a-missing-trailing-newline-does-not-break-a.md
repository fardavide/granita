# The marker for a missing trailing newline does not break a pair

§6 pairs maximal runs of deletions "immediately followed by" additions. Taken literally, no file
without a trailing newline is ever word-diffed, because git writes `\ No newline at end of file`
between the line it belongs to and the next one — which is every pair in such a file. Runs are
collected past those markers; the markers themselves are never paired and number neither side.

