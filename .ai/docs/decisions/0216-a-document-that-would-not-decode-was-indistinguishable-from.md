# A document that would not decode was indistinguishable from a first run, and got overwritten

`JsonDocumentStore` funnelled every read failure into an empty state: a file that existed and did not
decode returned `.empty` with nothing set on it, so the next mutation wrote over it — every project,
alias, pin and paired device, with no error anywhere. The blank state a reader saw was the same one a
first launch draws, which is why nothing about it looked wrong.

**The from-a-newer-version guard was defeated by the same path.** The version was compared only after
the whole envelope had decoded, and the envelope decoded the state with it. `StoredState`'s four
fields are all non-optional, so a future document that renamed or added one threw during decode, hit
the same `try?`, and was read as a first run — the exact outcome the guard and its doc comment exist
to prevent, in precisely the case that guard is for. The version is now decoded on its own and first:
it is the one field a later release is guaranteed to still spell the way this one does.

`isFromUnreadableDocument` became a typed reason rather than a flag, because the two cases reach a
reader as different sentences — one names a Granita to upgrade, the other a file to repair. A damaged
document refuses writes through `notWritable`, whose reason string carries the truth, so **no new
error case and no new reader-facing copy were needed**.

**Reset is the one deliberate act still allowed to land on bytes this version cannot decode.** It is
the only repair a reader has for a damaged document, and the first cut of this fix took it away
without noticing: flagging the document made every write refuse, including the one control that
exists to fix it. A document from a *newer* Granita is still refused — that one is readable, and by
something the reader may go back to.

> The tests were proved against the old logic rather than trusted: restoring it failed exactly the
> three new cases and nothing else. A fix for silent data loss whose test cannot be shown to fail is
> a fix nobody can check.

