# Granita

**Read the code your agent wrote, from your phone.**

Claude Code does most of its work in git worktrees, so at any moment there are several worktrees
across several projects, each holding uncommitted changes waiting to be looked at — and their
directory names are auto-generated, so they are impossible to tell apart. Reviewing that from a
phone means remote-controlling the Mac over VNC, which is slow and terrible on a small screen.

Granita is two halves of one product:

- a **macOS menu bar app** that holds a list of git projects you have explicitly added, enumerates
  their worktrees, computes diffs, and serves them over your local network;
- a **native iOS and iPadOS client** that renders those diffs properly on a phone — syntax
  highlighting, a directory-grouped file tree, word-level intra-line diff, mark-as-viewed, and the
  reading ergonomics of a real review tool.

v1 is read-only apart from worktree aliases and pins. You review on the phone, then talk to Claude
in the mobile app as usual. Inline comments and pushing feedback back into the agent are v2.

Nothing is exposed to the phone until you enable it explicitly, and the connection is TLS with a
pinned certificate — the payload is your private source code.

The full specification, including the empirically-verified traps the implementation must not
simplify away, is in [`SPEC.md`](SPEC.md).

## Stack

| | |
|---|---|
| Language | Swift 6, strict concurrency `complete`, every target |
| Minimum OS | iOS 26.0, iPadOS 26.0, macOS 26.0 |
| UI | SwiftUI — `MenuBarExtra` on the Mac, `NavigationSplitView` on the phone and iPad |
| Server | Hummingbird 2 on a `NIOTSEventLoopGroup`, in-process in the menu bar app and also a CLI |
| Git access | The `git` binary via swift-subprocess, behind a `GitClient` protocol |
| Persistence | One JSON document, actor-guarded, atomic replace. No SQLite, no SwiftData |
| Highlighting | Highlightr |
| Tests | Swift Testing, TDD, golden fixtures generated from the real `git` binary |
| Xcode project | Generated from `project.yml` by XcodeGen. Never hand-edited |

Exactly three external dependencies — Hummingbird, Highlightr, swift-subprocess — each pinned to
exactly one target.

## Layout

One local package holds everything testable; the two Xcode targets are thin `@main` shells over
it, so `swift test` runs the whole logic suite with no simulator and no Xcode.

```
Packages/Granita/<Unit>/<Feature>/<Layer>
```

A target's module name is its path with the slashes removed — `Client/Viewer/Data` is
`import ClientViewerData`. The layers are `Domain`, `Data`, `Presentation` and `Ui`, and the rules
between them are enforced by the target dependency graph in `Package.swift`, not by review: a
dependency a target does not declare is a dependency that does not compile.

## Build, test, run

```bash
make test        # package test suite — no simulator, no Xcode
make build       # compile-check the package and both apps
make run         # run the backend in a terminal
make project     # regenerate Granita.xcodeproj from project.yml
make fixtures    # rebuild the git fixture repos and the golden diff fixtures
```

`make help` lists the rest.

`main` is PR-gated: land every change through a pull request and wait for the checks.

## Changelog

### 0.0.9 — 2026-08-22
- **Nothing on screen has changed, and that is the whole entry.** This build carries the half of
  pairing that lives on the phone: the code to ask a Mac which version it speaks before spending a
  code on it, spend the code, keep the token in the Keychain where only this device can read it, and
  read every route the Mac serves. What is still missing is the camera screen that starts it, so
  none of it is reachable yet and there is nothing new to tap.
- **A Mac running an older Granita will say so instead of half-working.** The phone checks the
  contract version before it offers to pair rather than after, so a mismatch costs a sentence rather
  than a pairing code — which lasts two minutes and works once.

### 0.0.8 — 2026-08-22
- **Two pairs of words that sound alike are gone from the six-word code.** The list a Mac draws its
  spoken pairing code from held `amber` beside `ember` and `bacon` beside `beacon` — a problem only
  when the code is being read across a room, which is the one situation those words exist for. They
  are now `emerald` and `beetle`, and the list is held to that rule by a test rather than by a
  comment.

### 0.0.7 — 2026-08-21
- **Your Mac now serves over TLS, under a certificate only it has.** Granita generates its own
  ten-year identity the first time it runs, keeps it in your login Keychain, and serves everything
  under it. The certificate names the Mac by its `.local` name and by every address it answers on,
  so it works whether or not your network carries Bonjour between Wi-Fi and Ethernet.
- **A device pairs by scanning, or by typing six words.** The pairing link carries the fingerprint of
  that certificate, so a phone that has paired once will only ever talk to the Mac it paired with —
  something else answering on the same address is refused rather than trusted. When there is no
  camera to hand, six words do the same job: they are a second code for the same pairing, not a
  rendering of the first, and typing them in capitals with spaces works.
- **A pairing code is good for two minutes and one device.** Whichever way it is spent — scanned or
  typed — the other way stops working at the same moment, so a photograph of a code taken over your
  shoulder is worth nothing by the time anyone finds it.
- **Guessing at a pairing code stops after five tries a minute.** Counted per device rather than
  per Mac, so one phone with a stale code cannot lock the others out.
- **The connection log says which of the two things went wrong.** A code that was never issued and a
  code that arrived too late used to look identical in the Advanced panel. They are separate rows
  now — one means type it again, the other means be quicker — while the phone is still told the same
  thing either way, because a device that has not proved who it is should not learn which.
- **The Mac re-advertises itself after it wakes up.** A closed lid used to leave the phone unable to
  find the Mac until Granita was quit and reopened, with nothing anywhere saying why.
- **The log now records where a request came from.** It was showing the address the request was
  sent *to*, which is the same for every device on the network, so two phones were indistinguishable.

### 0.0.6 — 2026-08-21
- **The list of Macs no longer drops its arrow onto a second line.** A long device name pushed the
  row's disclosure arrow underneath the name, left-aligned, nowhere near where an arrow belongs. The
  row is a proper navigation row now, so the arrow stays on the trailing edge at every text size —
  and a name too long to fit is shortened **in the middle**, because two Macs called "MacBook Pro"
  and "MacBook Pro (work)" differ at the end, which is exactly what the old shortening threw away.
- **"Search Again" when nothing turned up.** If you started Granita on your Mac after your phone had
  already given up looking, the only way to make it look again was to quit the app. There is a button
  now, and it starts a genuinely new search rather than re-reading a dead one.
- **Looking for a Mac now looks like it is looking.** The antenna pulses while the search is running
  and goes still when it stops, so you can tell the two apart without reading the sentence under it.
- **A failed search says something you can act on.** It used to show whatever the system said, which
  was "The operation couldn't be completed" — the same sentence for every fault there is. It now
  explains what to try, offers a Try Again button, and prints the raw diagnostic in small type at the
  bottom, selectable, for pasting into a bug report.
- **The first-launch sentence mentions permission.** iOS puts its "allow local network access" alert
  over this screen, and the sentence behind the alert is the one that has to earn the tap on Allow.
  It now says permission first.
- **On iPad, the screen stops being a stretched phone.** Everything sits in a centred column instead
  of a name at one end of the display and its arrow 900 points away at the other.

### 0.0.5 — 2026-08-21
- **The Mac app now serves.** Granita on the Mac was an icon with a Quit item; the server it is
  supposed to run only existed in a terminal. Launching it now starts the same backend in-process
  and advertises it on the local network, and the menu says where — `MacBook-Pro.local:53614` — so
  "is it up" is answerable by looking rather than by opening Activity Monitor.
- **Settings opens from the menu, with a connection log in it.** Every device that reaches this Mac
  leaves a row saying what happened to it: served, and which device, or turned away with the reason
  — no pairing token, a token this Mac never issued, too many attempts, or an app speaking a newer
  version than this Mac serves. It is what makes a phone that will not connect explainable without
  attaching a debugger. A device that keeps polling keeps one row rather than filling all fifty.
- **The Mac advertises the name you gave the Mac.** It was announcing itself as whatever the network
  currently reverse-resolved to — on Davide's connection, `customer.mlnnita1.isp.starlink.com`.

### 0.0.4 — 2026-08-21
- **Coming back to Granita from the background no longer claims local network access is off.** iOS
  tears down the app's connection to the discovery daemon while it is suspended, and every browser
  dies with it — the same way a genuinely refused permission dies. Granita read that as a refusal,
  said so, and stopped looking, so the only way back to the Mac was to force-quit the app. It now
  starts a new browser instead, and reserves the refusal screen for one that will not come back.

### 0.0.3 — 2026-08-19
- **Reopening the app after refusing local network access now explains itself.** It said "Could not
  search" and showed a raw network error code. iOS reports a refused permission one way to the first
  browser an app creates and a different way to every one after that, and only the first was
  recognised — so the screen that offers to open Settings appeared once and never again.

### 0.0.2 — 2026-08-19
- **The phone now looks for your Mac.** Opening Granita browses the local network for a Mac running
  the server and lists what it finds, updating as Macs appear and go to sleep. Nothing can be read
  yet — selecting one does nothing — but the app is no longer a blank screen.
- **Refusing local network permission says so, and offers the fix.** iOS makes a denied browser look
  identical to one that is simply finding nothing, so that case is called out explicitly with a
  button into Settings rather than left as an endless spinner.
- **The Mac serves its first endpoint.** `granita-server` answers `/v1/health` and advertises itself
  over Bonjour, so the two halves can find each other.

### 0.0.1 — 2026-08-19
- **The project exists and builds end to end.** Both apps compile and launch empty, the backend
  runs from a terminal, and the test suite is green. The module graph for every feature is in
  place, so the layer rules are enforced by the compiler from the first commit rather than agreed
  in a document. Golden diff fixtures are generated from the real `git` binary and committed, so
  the parser suite has something to assert against before a line of it is written.
