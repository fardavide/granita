// CoreDiffDomain — the diff domain: the opaque identifier types, the change and hunk models, the
// unified-diff parser, per-line display-column arithmetic, and the word-level intra-line diff.
//
// The highest-risk component in the product, and the reason it is built first, test first,
// against golden fixtures, before any server or UI code exists. Pure logic, no I/O, and it
// compiles for iOS and macOS alike.
//
// Milestone M1.
