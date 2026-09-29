# An opaque identifier is a bare string on the wire

The second requirement M1 recorded and left open, and the spec carries no JSON example to settle it.
Decided: a bare string, not `{"rawValue": "…"}`.

The synthesised encoding of a one-field struct is the object, which is why this had to be decided
rather than inherited. The wrapper exists to keep three kinds of hash from being interchangeable at
compile time; it is not a shape the wire owes anyone, and an identifier has to be a string to serve
as a path component in a URL and as a key in a JSON object. `RawRepresentable` says the first part
and `CodingKeyRepresentable` the second — without it a dictionary keyed by an identifier encodes as
a flat array of alternating keys and values, which no other client would read as a mapping.

`FileChange` itself does not land with this. It needs a content hash, a status and a line count,
none of which exist until the change-set slice, and the decision this was blocking was the encoding
rather than the struct.

