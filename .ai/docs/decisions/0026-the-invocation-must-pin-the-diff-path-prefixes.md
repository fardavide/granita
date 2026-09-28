# The invocation must pin the diff path prefixes

The parser removes the leading `a/` and `b/` from every path. That is not ambiguous with a path that
genuinely begins with `a/` — git writes `a/a/file` — but the prefixes are **configurable**, and
`diff.noprefix` in Davide's own git configuration would silently remove the first two characters of
every path in the product with no error anywhere.

§5.1 hardens each invocation against his configuration but does not cover this one. The diff-family
suffix must therefore also pin the prefixes explicitly, alongside `--no-ext-diff` and `--no-color`.
Recorded here rather than fixed in place because the git layer does not exist yet; it is a
requirement that layer inherits, not a preference.

