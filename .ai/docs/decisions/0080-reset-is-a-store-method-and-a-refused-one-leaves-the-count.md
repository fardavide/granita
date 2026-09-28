# Reset is a store method, and a refused one leaves the count telling the truth

`Store.reset()` rather than the tab deleting the document, because the store owns what the document
means and is the actor that serialises writes against it. It goes through the same atomic replace as
every other mutation: a reset that cleared this process's memory and left the file alone would restore
everything it claimed to destroy at the next launch, which is the one outcome nobody would think to
check for.

**It is all four records rather than a choice of them** — projects, devices, aliases and pins, viewed
marks. A reset that left one behind would leave the reader believing the rest went too, and the record
most likely to be left is the one that matters: a project still enabled is a repository still being
served.

**The model swallows a refusal and re-reads the counts, which is deliberate.** A full disk or a
document from a newer Granita means nothing was destroyed. Because the sentence above the button is
counted from the store rather than remembered, re-reading it leaves that sentence describing what is
still there — and a tab that answered a failed reset with "nothing is stored" would be lying about the
one thing on this pane that is the security boundary.

