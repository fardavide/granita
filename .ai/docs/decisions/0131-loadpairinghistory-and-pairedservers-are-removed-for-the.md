# `loadPairingHistory()` and `pairedServers` are removed for the second time

The entry above them — *the row is right twice, and the second time it says: do not ship a screen's
API before the screen* — took these two out of this model once already, in the release that split
the pairing sequence into `Domain`. They came back with the pairing screens, and no screen reads
them: only their own tests did.

What they are waiting on has not moved either. Design §1's *Recent* and *Other Macs* sections are
the reader for this, and they need a join between a Bonjour instance name and a stored token — which
is the `serverInstanceID` in the TXT record SPEC §8 asks for and the Mac does not publish. Until that
lands, the discovery list ships as the single unlabelled section the design says it degrades to, and
a set of identifiers nothing can match against anything is a property no screen has agreed to.

`MacJoining.alreadyPaired()` **stays**, and so does the store method under it: they are `Domain`,
they are asserted where they happen in `MacPairingTests`, and they are what the section will be
ordered by on the day the record carries the identifier. What is removed is the copy held on a model
that draws screens, plus the `finish` step that maintained it — which, once it stopped inserting,
was a one-line rename of an assignment and is inlined at both call sites.

Written down a second time because the first entry did not stop it happening again. The rule is not
"delete these two properties"; it is that a model in a layer the Snapshot row measures may not carry
state that nothing renders, and the tell is a test being the only caller.

