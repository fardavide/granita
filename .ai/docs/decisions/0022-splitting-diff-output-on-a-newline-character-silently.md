# Splitting diff output on a newline `Character` silently merges every line of a CRLF file

Swift treats CRLF as a **single** grapheme cluster, so splitting on `"\n"` as a `Character` does not
split a CRLF file at all — it returns the whole diff as one line, with no error anywhere. The split
is on the newline **byte**. The CR that remains at the end of each line is content: it is what makes
the file a CRLF file, is preserved verbatim on the wire, and counts zero columns.

This is not theoretical: temporarily reverting the split to the `Character` form turns the CRLF
fixture's four lines into one, which is how the behaviour was confirmed rather than assumed.

