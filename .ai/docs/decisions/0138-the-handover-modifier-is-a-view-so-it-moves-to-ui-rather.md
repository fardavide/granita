# The handover modifier is a view, so it moves to `Ui` rather than joining the exempt list

The bound above cost the Unit row four tenths of a point, and reading the per-file export rather than
estimating found that almost none of it was the bound. **`PairedMacHandover.swift` was twenty-two
mapped lines, none of them covered, and nineteen of those are a SwiftUI body** — `body(content:)`,
the `onChange` closure inside it, and the haptic that closure calls. A host test has no renderer, so
it can reach exactly one of the file's seven regions: the `View` extension that builds the modifier.

Filed under `Presentation`, it sat in the one place where both scopes get it wrong, and the exports
say so rather than the argument doing. The Unit scope excludes a view body **wherever it lives**, but
it spells that as `…Screen.swift` — so this file was judged by the row that cannot execute a line of
it. The Snapshot scope selects a `Ui` module plus the screens composed from one, and this is neither
— so **the snapshot pass covered seventeen of its twenty-two lines and the Snapshot row counted none
of them.** Charged in full to the row that cannot see it, invisible to the row that does.

**So the file moves to `Client/Connection/Ui`, and no predicate changes.** That is the whole of the
fix, and it is the architecture's own answer: a `Ui` module is a vocabulary of stateless views, each
taking what it renders and reporting what happened, and this takes a `PairingState` and reports a
`PairedMac`. It never referred to a model or a `Data` target, so nothing about the move was
constrained — `Presentation` depends on `Ui`, so the two screens that apply it are unaffected beyond
the modifier becoming `public`.

> Rejected: adding it to `UNREACHABLE_FILES`. That set is for code unrunnable by construction for a
> reason that is *not* a layer — a keychain a test binary does not have, a camera, `NSApp` — and a
> view body already has a category of its own. Rejected: widening `is_screen_path` to catch a
> `ViewModifier`. It would be the right change if the file were in the right place, and it is not;
> it also renames both scopes and leaves the Unit, All **and** Snapshot rows unjudged for a run,
> which is the pull request that fell under the gate marking its own homework.

It does raise the Unit row, which is the test this file puts every rescoping to, so it is argued
rather than asserted: what leaves the denominator is nineteen lines no test kind this repository runs
could ever execute from the host, plus three that now count where they are covered instead of where
they are not. Nothing that a test could have reached stopped being counted.

### And the rest of the four tenths was real, so it is covered

Five regions of `MacPairing` had no test. `FirstAnswer` is **internal** now for the same reason the
patience beside it is: both of its guarantees are about the loser of a race — a second answer that is
dropped, and a first one still readable after it landed — and `answer(from:)` gives a test no say in
which of its two tasks wins. Through the sequence they are a coin flip; asserted directly they are
three sentences, one of which is the ending every stall actually produces, where the uncancellable
step finishes forty seconds after the reader has been told the attempt ended.

The contract read's refusal had none either, on either side of the boundary: `read()`'s `catch` and
the `case .failure` that turns it into `.refused`. It is the one refusal that costs nothing, which is
the entire reason that step goes first, and the assertion that says so is that no code was offered.

Five more of the sequence's own steps were covered while the export was open, because the claim above
is that there is no path out of pairing that is not an outcome and these were five of the paths
nothing held to it: what the handshake answers when it is asked what it trusted, which is the value
every later request is pinned to; an address no URL will hold on the spoken path as well as the
scanned one; a link carrying no query items at all, which is a different absence from an empty field
and reads as the first field being missing; a proxy answering 502 with HTML, where the status is the
only true thing left to say; and the two guards `GranitaHttpClient` puts on the way out — neither
reachable through a route, because every route is a literal path and every body is a type this app
wrote, and a guard nothing can provoke is one nothing holds to its sentence.

