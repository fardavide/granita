# `PairedMac` carries the Mac's name, because nothing else on that screen says which Mac

Design §5's last clause is that a pairing that works lands the reader on "the worktree list titled by
the Mac's name". 0.1.0 shipped it titled *Worktrees* and said so in a comment, which is the honest
version of not building something — and the reason it was deferred was real: `PairedMac` held a
device record, an address and a fingerprint, none of which is a name a reader would recognise, and a
`.navigationTitle` applied to the container in the composition root does not override one applied
inside the screen.

**The name is a field on `PairedMac` now, and it is passed into the pairing rather than derived.**
`MacJoining.pair` gained the `DiscoveredServer` beside the credential, because a credential cannot
supply this: a scanned link carries a host and six words carry neither, and a host is not the string
the reader saw. The one string that is, is the Bonjour instance's display name — the row they tapped
in the Mac list, and the title of all four pairing screens after it. So the list is titled with the
same words the three screens before it were, which is what makes the replacement read as arrival
rather than as a jump.

> Rejected: deriving the title from `PairedMac.address.host`. A Mac reached over `192.168.1.24` — or
> over the IPv6 literal the entry above this one bracketed — would put an address at the top of the
> one screen this product exists for. Rejected: reading it off `ClientConnectionModel.pairingWith`
> inside the model. That property exists to let a *retry* refuse a Mac it does not belong to, and
> spending it a second time as a data source would make one optional the source of two unrelated
> truths. Rejected: pushing a name beside the `PairedMac` on the navigation path. The path is
> type-erased on purpose; two values for one destination is how a screen comes to disagree with
> itself about what is on it.

**Every method that spends a credential now takes the Mac**, which is the shape `spendTypedWords` and
`spendAgain` already had and `readCode` did not. That is not symmetry for its own sake: the model is
one instance for the life of the app, so the Mac an operation is *about* has to arrive with the
operation rather than be read off state that outlives it. This is the same rule the cross-Mac retry
defect produced, applied one method wider.

### And the title is inline, which the name cost

The first render answered a question nobody had asked. A large title is 34pt bold and truncates at
the tail, so *Davide's 16-inch MacBook Pro* came back as *Davide's 16-inch Mac…* at 390pt and
*Davide's 16-inch…* in the iPad's 320pt sidebar — dropping exactly the half that distinguishes one
Mac from another, which is §1's stated reason for truncating these names in the middle rather than at
the end. A `.navigationTitle` cannot be given a truncation mode, so the direction is not available;
what is available is a smaller title. Inline is 17pt semibold, the whole name fits, and the list
gains back the 52pt a large title spends on every scroll.

Davide's call, 25 August 2026, against two rendered layouts rather than against an argument. The
alternatives it beat are in [`design.md`](../design.md) §2, and the frames that would have settled it do
not exist — §2's were deleted when §2 shipped, which is that rule working: what survives a drawing is
the argument, and this is one the drawing never had to make because §2's title was one word.

### What this name is not, and the case it gets wrong

**A QR scanned at one Mac while another Mac's screen is open is named after the one that was open.**
The spine is *Macs → this Mac → Scan*, so the viewfinder, the outcome and now the list are all titled
after the row the reader tapped; the link they hold up carries a host, a port and a key, and the
pairing goes to whichever machine those describe. Point the camera at the wrong Mac and the
connection is right and the label is wrong.

It is left that way rather than repaired, and the alternatives are why. A link carries no name, so the
only thing to fall back on is `link.host` — which is `davides-macbook-pro.local`, a string the design
spends §1 keeping off the screen. Comparing the link's host against the opened Mac's resolved address
would catch it, at the price of a resolution on the scanned path that path deliberately does not need:
the QR is the credential that already knows where it is going. What this costs is a wrong word on a
screen whose content is correct, in a sequence the reader had to leave halfway through to produce. The
mismatch is older than this entry — every pairing screen has been titled that way since 0.1.0 — and
what changed is that it now survives past the pairing.

