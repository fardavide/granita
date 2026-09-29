# Decisions are an index and one file each, because a log nobody can read is not consulted

28 September 2026. `decisions.md` had grown to 234 entries and 7,400 lines, about 510 KB — more than an
agent reads in one pass. So the instruction to read it before any non-trivial change was being met by
reading its headings, a slice found by search, and its end, in order to append. Davide, the same day:
*"Do you even read it? I think you just write into it."* He was right, and that is the failure the
file existed to prevent: a settled question that nobody can find gets re-opened.

**`decisions.md` is now an index**: one line per decision, stating the decision as a rule a later
change must respect, linked to its entry. Each entry is its own file under `decisions/`, numbered in
the order it was written, with its reasoning, measurements and rejected alternatives unchanged. The
index is about 63 KB, which is readable whole; an entry is read when the index points at it.

- **The split is mechanical and verified.** Every `## ` heading became a file, promoted to `# `, with
  the body byte-for-byte; rejoining the files reproduces every line of the original, and no heading
  sat inside a code fence. The only edits to entries are the eighteen relative links that moved one
  directory deeper.
- **The index lines were written by reading every entry**, not by summarising headings. An entry
  that a later one reversed outright is marked superseded; one that a later entry changed only in
  part states what still holds, and the later entry holds the rest.
- **Nothing that linked to `decisions.md` breaks.** No link anywhere pointed at a heading inside it,
  and the index keeps the file's name, so the 56 files that cite it still land on the right page.

**Adding a decision is a new file plus one index line, never reasoning appended to the index.** The
agent guide, the docs README and the two design skills say so, and the index's own header repeats it,
because the header is what the next writer reads.

> Rejected: distilling the log to the decisions still in force and archiving the rest. Smallest to
> read, but it discards the reasoning inline, and the reasoning is what stops a call being
> re-litigated.
>
> Rejected: keeping the single file and capping new entries. It stops the growth and leaves the
> 7,400 lines that already could not be read.
