# A launch resumes onto its own path value, because the browsed Mac's destination branches too early

Davide, 25 September 2026: the app opened at the Mac list every time, and *"usually, a developer has
a single machine"*. The fix is one line in principle — seed the stack with the Mac this phone last
opened — and the obvious spelling of it reintroduces the defect design §5 and 0.4.0 exist to have
ended.

**`ServerDiscoveryScreen` declares one destination for a `DiscoveredServer` and branches it** on
`ClientConnectionModel.isRemembered`, against a set that screen's own `.task` fills. A
`DiscoveredServer` seeded onto the path is resolved on the **first** pass, before that task has run,
so the answer is `false` — and `ChosenMacScreen` pins the answer in `@State` on purpose, so it never
corrects itself. A resume through that value would have opened the pairing screens for a Mac this
phone is already paired with, and gone on doing it: exactly the *"every open of the app asked for a
code again"* defect §5 records, arriving through a door marked *convenience*.

Reading the Keychain before seeding would settle the branch and costs the thing the feature is for:
the answer is needed before the first frame, and one that suspends puts the Mac list on screen for
the frame it takes. So the resume travels as **`ResumedMac`**, a value with one destination and no
branch, declared beside the other two in `PairingSpineScreen`. There are three declarations for two
ways out of the spine now, and the doc comment says why.

**The record is a preference, not a credential.** `LastOpenedMacPreference` holds a Bonjour instance
name and a display name in user defaults; `RememberedMacStore` keeps the pairing in the Keychain and
is still the only thing that says a Mac may be opened at all. The two answer different questions —
*which Macs* against *which one first* — which is what makes the losable home the right one: a reader
restoring onto a new phone lands on the Mac list, where every release before this one started. It
reads **both halves or neither**, because a record carrying an instance and no name resumes onto a
worktree list with nothing in its title.

**Where it is written down is the half that could have been wrong.** Not on the tap, which would
record a Mac whose pairing screen the reader is about to be shown — it is on the *appearance of the
worktrees*, in the closure the Mac list only draws in its remembered branch, and in
`PairingSpineNavigation.paired(with:)` on the other route. And `pairAgain` **clears** it: *Pair
Again* is the one control §8's refusal offers, so reaching it says the credential behind the resume
is in question, and a launch that went on assuming it would open a list that can only fail every
morning until the reader paired again.

**The resume stands down for a path it was given**, which is what keeps the snapshot suite honest:
every subject there opens at the push it is photographing, and a resume that took that over would
photograph a screen no baseline asked for on whichever machine happened to hold a record. The suite
passes a fake that has never opened one, so no picture depends on the defaults of the machine
rendering it.

**No design round trip, and that is Davide's call rather than a lapse.** No new pixels: the restored
screen is §2's worktree list in §8's existing loading and failure states, and no baseline moved. The
calls are written into [design §1](../design.md) in this repository's voice with what each one beat,
which is what a return would have left behind — the same waiver 0.8.0's syntax highlighting took.

**What is deliberately not built is the deeper resume.** Davide named coming back to an open worktree
as *"not a strict requirement"*, and it is a different question with a different answer: the worktree
list is the screen the reader was going to reach anyway, and a file list is somewhere they did not ask
to be this session.

