# Arguments are bytes, and so is a repo-relative path

A path on disk is a sequence of bytes with no encoding attached. Decoding one to build an argument
vector substitutes a replacement character, and re-invoking on the result addresses a file that does
not exist — silently, because U+FFFD is a perfectly ordinary filename character.

So the vector is `[[UInt8]]` and a repo-relative path carries its bytes, with text as the lossy
projection for display and for the wire rather than the other way round. This is the shape M1
anticipated when it gave `FileID` a byte-based derivation.

The checkout's own location stays a string. It comes from `git worktree list` or from Davide picking
a folder, it is never accepted from a client, and treating a directory Davide chose as undecodable
buys nothing.

