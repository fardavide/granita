# Three settled gaps in the diff model, and one spec error

Found while planning M1 against the committed fixture corpus.

**SPEC §5.3 was wrong about renames in `--numstat -z`.** It said the format emits "an extra empty
field" before the paths and that a parser should detect a rename by that field. There is no
zero-length NUL field anywhere in the stream; what marks a rename is a **trailing TAB** inside the
first field, so the record spans three NUL fields rather than one. A parser following the old wording
reads every rename as an ordinary record. Corrected in place, verified against the fixture. This is
the first thing in the spec found to be actually incorrect rather than merely incomplete — and it sat
inside a paragraph warning that a naive splitter desynchronises here.

**`DiffLine` gained `needsMeasurement`.** §6 and §10 both require the client to measure
unpredictable lines for real, and §4's model had no field to say which. A plain `Bool`, always
encoded: an absent key meaning false is the ambiguity §8's PATCH body already works around, and
re-deriving the judgement on the client would duplicate the Unicode logic on both sides where a
disagreement is a row-count error in the scroll.

**Control characters count 0 columns, and East Asian Ambiguous counts 1.** Neither is in §6. Read
literally, "everything else counts 1" gives `first\r` six columns for a line occupying five, so every
CRLF line would over-measure — and CRLF is preserved verbatim in `text`, so the CR is content that
renders nothing. Ambiguous characters (`è`, `—`) are narrow in the monospaced fonts the viewer uses,
and flagging them would push ordinary European prose onto the slow measured path.

