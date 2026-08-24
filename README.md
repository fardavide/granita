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

### 0.0.19 — 2026-08-24
- **The worktree sidebar is built, and nothing in the app opens it yet.** It needs a paired Mac, and
  pairing has no screen, so there is deliberately no way to reach it: a row leading to a screen that
  cannot load is worse than no row at all. It arrives with pairing.
- **What it will show when it does.** Every checkout an agent has been working in, grouped by project
  or flat and most recently changed first, with what the worktree is called, how many files moved,
  how much was added and removed, and how long ago. Pinned worktrees sit above everything in both
  arrangements.
- **Renaming a worktree names it on your phone and never touches git.** Swipe a row to rename or pin
  it. The rename sheet offers the summary Claude Code wrote for that session rather than filling the
  field with it, and its footer always says what the row will read once you save — including what it
  falls back to if you clear the field.
- **Worktrees with nothing changed are hidden, and the list says how many it hid.** That line is
  tappable, so the count and the way back to those rows are the same control.

### 0.0.18 — 2026-08-24
- **The verbose switch is on the Advanced tab, and it takes effect on a server that has been running
  since you opened the app.** It is a switch rather than five log levels: there is one reader here,
  and either the normal amount of detail is wanted or all of it. Turning it on records every request
  and every git invocation; refusals and failures are recorded either way, and the tab says so, so
  nobody leaves it on for a week waiting to catch something that was being written all along.
- **The switch in the menu bar app and the one for `granita-server` are two switches.** An executable
  has no bundle identifier, so the app writes to `dev.fardavide.granita.mac` and the terminal reads
  the global domain. The app's is this new toggle; the terminal's is
  `defaults write -g granita.diagnostics.verbose -bool YES`.
- **Open in Console, beside it.** `Console.app` registers no URL scheme and cannot be handed a
  filter, so pressing this copies `subsystem == "dev.fardavide.granita"` to the clipboard and opens
  Console — paste it into the search field. The tab says that too, because a Console window that
  opens unfiltered is a button that appears to have done nothing.
- **Two Granitas can no longer both hold this Mac's settings.** A lock file sits beside the document
  and the second process to start refuses: it does not serve, and it says which process has the
  settings and what its process identifier is. Read on General, where the advice is to quit that
  process rather than to check Local Network access, and again on Advanced. Both the menu bar app
  and `granita-server` refuse the same way; the terminal prints it and stops.
- **A refused lock is a state of its own rather than a failure wearing a different sentence.** Every
  other way the server fails to bind is worth checking Local Network access for, and this one is
  not — pointing you at a settings pane that is already correct is worse than saying nothing.
- Granita has no Dock icon and no window whose red button ends it, so the blocked screen carries a
  **Quit Granita** button — otherwise it names something you have no way to do from the screen
  telling you to do it.

### 0.0.17 — 2026-08-24
- **Granita writes a log now, and until this release it wrote nothing at all.** Not a line, anywhere
  — which is why the Advanced tab's verbose switch and *Open in Console* have been missing: they
  were controls over a subsystem that emitted silence. Every request the Mac answers and every git
  command it runs is recorded, under the subsystem `dev.fardavide.granita`, so Console can be
  filtered to Granita and nothing else.
- **A failure is always written down; the rest waits to be asked for.** A git command that could not
  be run, or a request that was refused, is recorded whatever the setting — a fault you have to
  switch logging on to see is one you learn about after it mattered. Everything else — each request,
  each git invocation — is the detail the verbose switch will turn on.
- **What is logged is deliberately not what git said back.** The command and the checkout it ran in,
  never its output; the method and the path of a request, never its query or its body. Your source
  stays on your Mac, which is the point of the product, and a log has a longer life and more readers
  than the thing it was taken from.
- The switch itself, and the button that opens Console, arrive with the next release alongside the
  lock-file row — all three are on the same tab. Until then the detail is turned on by hand:
  `defaults write dev.fardavide.granita.mac granita.diagnostics.verbose -bool YES` for the menu bar
  app, and `defaults write -g granita.diagnostics.verbose -bool YES` for `granita-server`, which has
  no bundle of its own to keep preferences in. Read it back with
  `log show --last 5m --predicate 'subsystem == "dev.fardavide.granita"'`.

### 0.0.16 — 2026-08-24
- **The menu bar item now does things instead of only saying them.** The status line is a button:
  press it and this Mac's address is on the clipboard, ready to paste into a phone or a terminal. It
  copies the same `macbook-pro.local:59144` the General tab copies — no scheme, because Granita
  serves TLS under its own certificate and pasting `https://` into a browser produces a warning
  rather than an answer.
- **Pair a device… is in the menu.** It opens Settings straight to the QR, which matters because
  Granita has no Dock icon and no window: when a phone is in your hand, the menu is the whole app.
  It is greyed out when the server is not running, since there is no address for a code to carry.
- **When the server has not come up, the menu leads with it.** *Not serving*, and directly under it
  **Open Local Network Settings…**, which is where the overwhelmingly common cause is fixed. The
  diagnostic itself stays one click below, on General, where there is room to say it is a likely
  cause rather than a certainty.
- **The status item has three symbols rather than four.** A server that fell over and a server macOS
  is blocking now look the same in the menu bar, because the menu bar answers one question — can
  your phone read this Mac — and both are the same answer to it.
- **Settings reopens on the pane you left it on**, and on **Projects** the very first time, because
  until a repository is switched on there is nothing for a phone to read.

### 0.0.15 — 2026-08-23
- **Settings has a Devices tab, and it is where a phone gets in.** A QR code big enough to scan from
  across a desk, the six words underneath it for when the camera will not cooperate, and a bar
  counting down the two minutes a code lasts. The words are a real second credential, not a caption:
  either one pairs the same device, and either one dies when the other is spent.
- **Every phone that has paired is listed, with a Revoke beside it.** Each row leads with the fact
  that is true — the platform and the day it paired — and adds *Seen 4 min ago* only when this Mac
  has actually served that device since Granita started. A device it has not heard from says so, and
  says how far back it has been listening, rather than showing a stale date that reads like an
  accusation.
- **A code that ran out says so instead of quietly failing on the phone.** The QR dims behind *Code
  expired* with a **New Code** button, because from the phone's side an expired code and a wrong one
  look exactly the same.
- **A refused connection now offers to fix itself.** In the Connections tab, a device turned away for
  having no token gets **Pair…**, and one whose token this Mac never issued gets **Pair Again…** —
  both open the Devices tab. Version mismatches and rate limiting get no button, because there is
  nothing on this Mac to press for either.

### 0.0.14 — 2026-08-23
- **Settings has a Projects tab, and it is where you decide what your phone may read.** Nothing on
  this Mac is visible until you add a repository here and switch it on, and those are two separate
  acts on purpose. Each row shows the switch, the name, the folder, and how many worktrees are behind
  it.
- **Scanning a folder never adds anything on its own.** Point Granita at where you keep your work and
  what it finds opens in a sheet, with nothing ticked and no *Select All*. The button counts what it
  will do — *Add 2 Repositories* — and everything it adds arrives switched off.
- **A project whose folder moved says so instead of looking empty.** Until now it stayed switched on
  and served nothing, which on the phone is indistinguishable from a project with nothing to read.
  The row now reads *Folder not found*, keeps the last known path, and offers **Locate…** — and its
  switch is disabled rather than quietly turned off behind your back.
- **How many worktrees have uncommitted work arrives a moment after the list does.** Asking git that
  question costs about a second per worktree — sixteen seconds for one Android monorepo — so the tab
  opens with what it knows and fills the rest in while you look at it.

### 0.0.13 — 2026-08-22
- **Settings has an Advanced tab, and it is last.** It holds the rows you set once and the one button
  you hope never to press — which is exactly why the connection log moved out of it in 0.0.11.
- **The git row runs git rather than pointing at it.** Granita picks the first git it finds that is
  executable, and a git that is executable and broken looks identical to a working one until
  something runs it. The row shows the version first and the path second, and when git cannot run it
  carries git's own words — so *xcrun: error: invalid active developer path* is what you read, rather
  than an empty list of worktrees with no explanation.
- **Reset All Data says what it will destroy before it does it.** The row counts what is stored, and
  the confirmation repeats it as consequences rather than nouns: each paired device has to pair
  again. If the reset cannot be written, nothing is destroyed and the count still says so.
- **The data folder is one click from Finder**, for when the document is worth looking at by hand.

### 0.0.12 — 2026-08-22
- **Tapping your Mac used to do nothing at all. Now it tells you why.** The row was a navigation row
  with a chevron and nothing behind it, so the one thing you open the app to do answered with
  silence — no screen, no message, nothing to distinguish it from a broken app. It now opens a screen
  saying Granita can find your Mac but cannot connect to it yet, because pairing needs the camera and
  that screen is still being built. **Shipping a control that looks like it works and does not is not
  something this app will do again**; when the work behind something is not finished, it says so.

### 0.0.11 — 2026-08-22
- **The connection log has its own tab.** It was sharing Advanced with the button that erases
  everything, which is a bad place for the one panel you open while annoyed. It is now *Connections*,
  and Advanced keeps the settings you touch once.
- **A row says how many times it happened.** The log folds a device repeating itself into a single
  row so one polling phone cannot bury the row explaining another — and, until now, that also turned
  four hundred attempts into something that looked like one. *Tried once* and *has been hammering
  this Mac for ten minutes* are different problems, and the row now tells them apart.
- **Each row is shorter and says more.** The word "Refused" is gone, because the mark beside it
  already says so forty-five times down a list; the space pays for the address the attempt came from
  and the count. Underneath, a footer says how far back the panel goes and how full it is.

### 0.0.10 — 2026-08-22
- **The Mac's Settings window has a General tab.** It shows the address this Mac is serving on, with
  a button that copies it, and it says who chose the port — macOS does, when Granita advertises
  itself, which is why it differs every launch and why your phone finds this Mac by name instead.
  Beside it, when the server started, and a Restart for the case a wake did not fix: a laptop that
  changed network keeps running and quietly stops being reachable, and nothing tells the app so.
- **When Granita is not serving, the tab says what to do about it.** Our sentence, our button
  straight to Privacy & Security › Local Network, and macOS's own error underneath in small print —
  rather than an `NWError` code being the whole explanation for an app that does nothing.
- **Granita can open itself at login, and will not pretend it did.** macOS normally accepts the
  registration and then waits for you to approve it in Login Items, which means nothing starts at
  the next login — so the switch goes back off and says so, with a button that opens the right pane.
- **The menu bar carries no count of changed worktrees.** It was specified and drawn, and producing
  the number turned out to cost 122.7 seconds against real repositories, so the icon stands alone
  until something can ask git the cheap question instead.

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
