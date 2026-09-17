# Changelog

Every release of Granita, newest first. Entries are user-facing: what changed for someone reading
diffs on their phone, not what changed in the code.

The version lives in one place — `MARKETING_VERSION` in `project.yml` — and every bump carries its
entry here in the same pull request. Merging to `main` publishes the phone app to TestFlight; the Mac
app is built by hand.

### 0.14.2 — 2026-09-17
- **The review you copy now quotes your code as code.** Every excerpt used to go over with a `> ` in
  front of each line, which is a character the agent has to strip off before it can search the file
  for what you handed it. It is a fenced code block now, tagged with the file's language, so the
  agent reads it the way it reads anything else — and so do you, if you paste it somewhere that
  renders.
- **Each comment is lettered, so you can talk about one.** The document labels them `A.`, `B.`, `C.`
  in the order you meet them scrolling. The point is the reply: ask your agent to answer each point
  by its letter and you can follow what it did without matching paths and line numbers back by eye —
  which matters most after you clear the review, when the letters are the only handle left.
- **A rule stands between comments**, because four of them with nothing but a blank line in between
  read as one wall of text.
- **The opening line is just `Review of uncommitted changes` now.** It used to name the project, the
  worktree and how many files had changed — all three of which the session you paste into is already
  sitting in.
- **A quoted Markdown file cannot break the document any more.** If the lines you commented on
  contain a code fence of their own, the block around them grows longer than anything inside it.

### 0.14.1 — 2026-09-16
- **The worktree list refreshes when you come back to the app.** It already re-read every time you
  returned to the *screen*, but a screen that was in front of you when you put the phone down never
  goes away and so never comes back — which meant the list you found after lunch was the list you
  left, with nothing but the age in the footer to say so.
- **A glance elsewhere still costs nothing.** It only re-reads when what is on screen was read more
  than thirty seconds ago, so pulling down Control Center and letting it go leaves your Mac alone —
  it may well be asleep, and a read wakes it. Anything older than that is re-read, whether you were
  away for a minute or for two seconds of a much longer sitting.
- **It reports itself the way any other unasked-for read does** — the same small spinner beside the
  Mac's name, after the same half-second wait, with your rows staying put and operable throughout.
- **An open diff is unchanged.** Re-reading a change set replaces every file in it, and doing that
  under someone halfway down a scroll would move the code they were reading.

### 0.14.0 — 2026-09-15
- **A changed screenshot now shows you both screenshots.** Until now every picture in a change set
  was a shut row reading `binary · no diff to show`, with no way to open it — which on a branch whose
  point was re-recording snapshot baselines meant the one thing you wanted to look at was the one
  thing you could not. A changed image draws the committed version and the working one side by side,
  in the card where a source file draws its hunks.
- **Tap either one to see it at the size of the screen, and hold to see the other.** Side by side on
  a phone gives each version about 170 points, which tells you *that* something moved; the picture
  itself is a tap away, and keeping your finger down swaps it for the other version in exactly the
  same pixels. That is the only way two screenshots differing in one place can be compared on a
  phone. A file that was added or deleted has just the one picture and does not offer the hold.
- **A picture that is still coming, or that your Mac would not send, says which.** Empty grey frames
  are the one thing a picture viewer must never leave you with. A side still arriving says so, one
  your Mac refused says so and carries its own *Try Again*, and one that arrived and will not decode
  says that instead — three different problems with three different answers.
- **Screenshots up to 12 MB.** Big enough for an iPad baseline, which is what this was built for.
  Anything larger is refused outright rather than shown in half, because half a picture is not a
  smaller picture.

### 0.13.0 — 2026-09-15
- **You can now see when Granita is fetching from your Mac.** Both the worktree list and a
  worktree's file list re-read every time you come back to them, and until now they did it in
  complete silence — the rows you were looking at were the old ones for as long as the read took,
  with nothing anywhere saying so. A small spinner now turns beside the Mac's name, or the
  worktree's, for as long as that read is running.
- **It waits half a second before appearing.** Most of these reads answer faster than that on a
  local network, and a spinner that flickered into the title bar every single time you pressed Back
  would be reporting a wait you never had.
- **Pulling to refresh and pressing Try Again are unchanged.** Those are reads you asked for, and
  they keep the feedback they already had.

### 0.12.2 — 2026-09-14
- **A worktree opens on its diff instead of on a band of empty grey.** The first file sat 92pt down
  the page — a third of the visible code on a phone — and one flick of the scroll hid the evidence,
  which is why it survived every release since the screen was built. The screen told itself to put
  the first file at the top of the scroll's frame, and the frame begins under the navigation bar,
  where the content is already inset by exactly that much: the same measurement, applied twice.
- **Nothing about jumping to a file changed.** Tapping a file in the list still puts it where it
  always did; the only position that stopped being asserted is the one nobody asked for.

### 0.12.1 — 2026-09-13
- **A file that has not arrived draws a short placeholder instead of a full-height one.** 0.12.0
  sized it from the line count your Mac reports, which cannot include the expanders a drawn file
  gets — so a long file reserved most of a screen and then landed somewhere else entirely.
- **The diff now moves into place instead of snapping.** The placeholder fades into the code and the
  file grows to its real height on the same curve everything else on this screen opens with.

### 0.12.0 — 2026-09-13
- **A file you are waiting for now says so.** Where a diff that had not arrived drew an empty card
  under its header, it draws the rows the file has not sent yet — one line of type saying
  `reading from your Mac`, and a slow sweep of light across the card. After ten seconds the line
  reads `still reading from your Mac`. Nothing moves when the real diff lands.
- **A diff that never arrives no longer looks like one that is still coming.** A file whose batch
  your Mac refused stops sweeping, dims, and says `couldn’t read this file` — where before it stayed
  blank for as long as the screen was open, with nothing anywhere explaining why.
- **And there is something to press about it.** A bar at the bottom of the diff says how many files
  could not be read and why, and offers the one action that can help: **Try Again**, or
  **Pair Again** when the pairing was revoked, or **Back to Worktrees** when the worktree is gone.
  Trying again re-asks for every file that failed.

### 0.11.4 — 2026-09-13
- **Opening a Mac explains what Granita is waiting for.** Finding a route, checking the paired
  key and reading worktrees have distinct labels. Long waits show elapsed time and offer Copy Logs.
- **Refresh keeps your worktrees available.** Pull to refresh, retry a stale read inline, and see
  when the list was last read. Opening a worktree or leaving cancels the pending list read.
- **Revoked pairings offer Pair Again.** The action opens the selected Mac's pairing screen.

### 0.11.3 — 2026-09-12
- **Opening a remembered Mac over Tailscale no longer waits for local discovery first.** On
  cellular, local discovery and wake retries are skipped; on Wi-Fi, the first route to complete
  pinned HTTPS verification wins. Health probes have a five-second deadline without shortening
  worktree or diff requests.
- **Copy Logs now shows where connection time goes.** Reports include local discovery,
  route verification and request durations, without credentials or source text.

### 0.11.2 — 2026-09-12
- **Pinned HTTPS connections over Tailscale now complete.** The phone no longer rejects the
  Mac's self-signed certificate after its saved public-key pin matches. The exception is limited
  to Tailscale's IPv4 range; connections still use HTTPS and the same pairing identity.

### 0.11.1 — 2026-09-12
- **Copy Logs now includes certificate-check outcomes.** Connection reports show whether the
  phone reached Granita's TLS trust check and whether the Mac matched its saved public-key pin,
  helping diagnose remote connection failures without visiting your Mac. Certificate checks and
  pairing security are unchanged.

### 0.11.0 — 2026-09-12
- **Error screens now explain what happened without a wall of technical text.** Discovery, pairing,
  worktree and diff failures keep their recovery actions alongside clearer, accessible messages.
- **Copy Logs lets you share a connection report directly from your phone.** It copies the app
  version, timestamps, connection endpoints and error codes from the current app session, without
  credentials, pairing codes, request bodies or source text. No Mac, archive or share sheet is needed.

### 0.10.1 — 2026-09-12
- **Remembered Macs now appear when Granita opens away from the local network.** A cellular-only
  launch previously remained on Searching because Bonjour did not report an empty result. Granita
  now surfaces paired Macs with stored Tailscale addresses immediately, while still preferring
  Bonjour whenever it returns.

### 0.10.0 — 2026-09-11
- **Granita now reconnects to a paired Mac through Tailscale.** Keep the existing Tailscale apps
  connected on the Mac and phone: Granita still prefers Bonjour on the LAN, then uses the Mac's
  stable tailnet address when local discovery cannot reach it. Existing pairings learn that address
  on their next successful local connection, so they do not need to be paired again.
- **First pairing still happens on the local network.** Once that pairing exists, the same pinned TLS
  identity and device token protect both the local and Tailscale connections.

### 0.9.2 — 2026-09-07
- **Tapping a worktree in the sidebar now opens it.** In the split-view layout — an iPad in a regular
  width, or the Client running on a Mac — the row highlighted and nothing happened. The sidebar was
  declaring its own destination for the tap alongside the split view's, and the nearer one swallowed
  it before it could reach the column meant to show it.
- **The sidebar uses the system's own sidebar look** in that same split-view layout, instead of a
  plain list.

### 0.9.1 — 2026-09-05
- **Deleting a worktree works.** It did not, on any worktree Claude Code made — which is nearly every
  worktree Granita shows. Claude Code marks each one it creates as locked, Granita read that as
  somebody at the Mac saying leave this alone, and refused. The confirmation now tells you the
  worktree is locked and deletes it anyway, because you are the one who put the lock there.
- **Renaming a worktree is instant.** The sheet stayed up and the row kept its old name until the Mac
  answered, and the Mac was answering by re-reading every worktree of every project you have enabled
  first — which on a handful of real repositories is minutes. The sheet now closes on Save, the row
  reads the new name immediately, and the Mac only looks at the worktree you renamed. If it refuses,
  the name goes back and Granita says so.
- **Pinning is instant too**, for the same reason and by the same route.

### 0.9.0 — 2026-09-04
- **Your phone wakes your Mac.** A Mac that has gone to sleep used to be a Mac that simply was not
  there — nothing in the list, nothing to tap, and no way to tell it apart from one that was
  switched off. Opening Granita now sends the Macs you have paired with the packet their network
  card listens for while they sleep, and they turn up in the list a few seconds later on their own.
- **Opening a sleeping Mac waits for it instead of giving up.** Granita used to ask once, wait five
  seconds and tell you it could not be reached. It now asks again as the Mac comes back, over about
  fifteen seconds, so the wait you see is the Mac waking rather than an error about a Mac that is
  fine.
- **A Mac you have just paired with recovers on its own.** Before, if it slept while that screen was
  open, *Try Again* went on dialling an address that had stopped existing until you left the screen
  and came back. It now looks the Mac up again, which is also what lets it be woken from there.
- **Macs you paired with before this version learn to be woken on their own.** The first time your
  phone reaches one, it asks how to wake it and remembers the answer, so you never have to pair
  again just to get this.
- **One thing you have to switch on yourself, once.** On your Mac, System Settings › Battery ›
  Options › *Wake for network access* has to be **Always**. On battery it usually ships as *Only on
  Power Adapter*, and a Mac on battery will not wake for anything Granita sends.

### 0.8.0 — 2026-09-04
- **The code is syntax highlighted, in light and in dark.** Keywords, strings, comments, types and
  numbers are coloured the way Xcode colours them, because the code you are reading on the phone is
  the code you write on the Mac beside it.
- **The changed words still stand out.** A word-level change is a background and the highlighter
  only ever colours text, so the two read together rather than fighting: a renamed argument is a
  green patch over code that is still coloured.
- **A file arrives plain and gains its colours a beat later**, and nothing moves when they land. The
  file you are looking at is coloured before the ones fetched ahead of you.
- **Files that cannot be coloured stay plain and say nothing about it** — anything over 4,000 lines
  or 100 KB, and any file whose kind your Mac could not name from its extension.
- **Conflict markers are never coloured.** `<<<<<<< HEAD` is not code in any language, and a
  highlighter handed one gets every line after it wrong.

### 0.7.1 — 2026-09-04
- **The screens you see before you have opened a Mac now use the whole window.** Finding a Mac,
  choosing between the QR code and the six words, the viewfinder, the six-word field and the receipt
  were all drawn in a 420pt column down the middle, with the rest of the window empty white either
  side of it — on an iPad, and most visibly on a Mac. They lay themselves out at whatever width they
  are given, the way everything else does.

### 0.7.0 — 2026-09-03
- **You can leave comments on the code now, and send them back to the agent that wrote it.** Tap the
  line numbers beside a line to write one. Press and hold a line, then tap another, to comment on a
  run of them.
- **A comment is a thin indigo bar beside the lines it is about**, as long as the run it covers, and
  the file's header says how many the file carries. Nothing moves when you write one: the diff you
  were reading stays exactly where it was.
- **A *Review* button appears in the corner once you have written something.** It never disappears
  while you scroll, because that is when you are writing.
- **The review is one screen**: an optional note for the agent — or Skip — and every comment in the
  order the diff draws them. *Show text* reveals exactly what will be copied.
- **Copy it, and only then are you offered a way to clear it.** The comments live on this phone and
  nowhere else, so the button that throws them away appears after the one that sends them, never
  before, and it asks first.
- **Tap a comment's bar to edit it, swipe it in the review to delete it.**
- **A comment whose lines the agent has since changed says so** rather than disappearing — it moves
  to a row under the file's name and is still included when you copy.
- **On iPad the review is a column** that takes the file tree's place, so the code keeps its width.

### 0.6.2 — 2026-09-03
- **A changed file no longer opens onto nothing.** Some files showed their name and their `+`/`−`
  counts and then an empty body, however long you left them — and it was the same files every time
  you opened that worktree, while the files either side of them were fine. The Mac was asking git
  about a filename with a few stray bytes stuck on the end, which matches no file, so git answered
  that nothing had changed and said so without complaint. Every file's diff now arrives.

### 0.6.1 — 2026-09-01
- **Files are actually separated now.** 0.6.0 put ten points between them and made those ten points
  the same white as the files, so there was nothing to see. The diff sits on a grey page and each
  file is a card on it, which is what makes the gap a gap.
- **The grey band is now a tear across the page.** Where the diff skipped something you get a torn
  row — torn along the top if the lines are missing above, along the bottom if they are below, along
  both if they are in the middle — saying how many lines are hidden and, going up, which declaration
  you are inside. Tap the row to open it; between two changes there is a control for each direction.
- **A file the diff drew whole has no band at all.** There is nothing to reveal, so there is nothing
  to press, and a row that could never do anything is not drawn.
- **A file that shuts stops shifting sideways.** The open header and the bar that replaces it drew
  their name, their status and their counts in two slightly different columns, which was visible down
  a long change set. One column now.
- **The `+` and `−` beside a line have room before the code now**, so a changed line with no
  indentation no longer reads as one word starting with a minus sign.
- **A file that added nothing says nothing about additions.** `+84 −0` is now just `+84`, and a
  binary file or a rename that changed nothing shows no counts at all instead of `+0 −0`.
- **The counts on a shut file no longer run off the edge of the screen.** `+1,240 −318` was losing
  its last figure under the bezel on exactly the biggest files.
- **Tapping a file in the list shows you it was tapped, and lets you see where it went.** The row
  highlights under your thumb, and if you had pulled the list up over the whole screen it drops back
  to half height so the file you asked for is behind it rather than hidden by it.

### 0.6.0 — 2026-09-01
- **A removed line has a number again.** It never had one: the gutter held the line number of the
  file as it is now, and a removed line does not exist there — so the one row that says something was
  taken away was the one row you could not point at. Every row carries a number now.
- **`+` and `−` beside every changed line.** Colour was the only thing saying which side a line was
  on, which fails for red-green colour blindness, fails in sunlight, and fails the moment you paste a
  screenshot into a chat that dims images.
- **A long line fades at the edge instead of stopping dead.** `extension Lce: Sendable where C:
  Sendable` is 57 characters and the row fitted 56, so it looked finished and was not. There is a
  scroll indicator under each hunk now, so you can see there is more to the right before you go
  looking for it.
- **The code got room and the chrome gave it up.** Rows go from 13.7pt to 18, the grey band between
  hunks from 43pt to 26, and files are separated rather than running into one another.
- **A file says its name, then where it lives.** `…out/Presentation/Models/AboutState.swift` threw
  away the module, which is the only thing telling eleven files apart when three of them are in a
  folder called `Models`.
- **Marking a file read is a real target.** It was a 21pt ring against the edge of the screen; it is
  44pt now, it fills green, and the file it belongs to goes quiet — so on a long review you can see
  where you got to.
- **The iPad's file list folds away.** Press the sidebar button to give the whole window to the code,
  and the *Files* button comes back while it is folded. The iPad also draws code a point larger, which
  is about 110 characters without wrapping.

### 0.5.3 — 2026-08-31
- **Opening and shutting a file now really does move.** 0.5.2 said it did, and only the lines around
  a hunk actually travelled: tapping a collapsed bar still snapped every file below it into its new
  place in one frame, with a fade over the top. The whole scroll slides now, so the file you were
  reading goes where you can watch it go.

### 0.5.2 — 2026-08-31
- **Opening and shutting a file no longer snaps the screen out from under you.** Tapping a collapsed
  bar, shutting a file you have finished, expanding the lines around a hunk, and opening or closing a
  folder in the file list all move now instead of jumping. The diff below the tap slides to where it
  is going, so you can see where you were and follow it there.

### 0.5.1 — 2026-08-31
- **On iPad, a Mac you have already paired with opens its worktrees across the whole window.** It
  used to open them inside the narrow centred column the pairing screens use — a squeezed sidebar,
  a sliver of a detail column, and white down both sides of the screen. The column is for getting
  connected; once you are reading worktrees, the iPad gets the room it has.

### 0.5.0 — 2026-08-28
- **You can delete a worktree from your phone.** Long-press a row in the worktree list and choose
  *Delete Worktree…*. Your Mac removes the checkout and everything uncommitted in it; the branch
  stays where it is. It is the first thing this app has ever changed on your Mac beyond a name and
  a pin.
- **The confirmation says what you are about to lose, not just what it is called.** It names the
  worktree in full, and then how many files have changes that were never committed and by how much
  — because there is no undo behind it, and nothing on your Mac keeps a copy.
- **Deletion is deliberately not on the swipe.** Swiping still pins and renames, and a full swipe
  still pins. A long press is a gesture you have to mean, which is the point for the one control
  here that destroys work.
- **Two rows say why they cannot be deleted rather than staying silent about it.** The project's own
  checkout, and any worktree locked on your Mac. Both appear in the menu with the reason, so a row
  that will not delete is never confused for an app that is not working.
- **A worktree being deleted says so while it happens** — it dims, reads *Deleting…*, and cannot be
  opened, renamed or pinned until your Mac answers. The row goes only once your Mac confirms it is
  gone, so nothing ever disappears from the list that is still sitting on the disk.
- **If your Mac cannot be reached mid-delete, Granita says it does not know** rather than guessing.
  Deleting again is safe: if it has already gone, the row simply goes.

### 0.4.2 — 2026-08-28
- **The words that changed within a line are marked by a highlight behind them, not by dimming
  everything else.** A line where one word moved used to grey out the rest of it so the changed part
  stood out; now the whole line reads at full strength and the changed words carry a stronger green
  or red behind them. It is easier to read, and it leaves the text's own colour free for the syntax
  highlighting that comes next.
- **The highlight is the same amount stronger in light and in dark.** Two see-through layers stack
  rather than add, so a fixed shade lands differently against white and against black. What is fixed
  now is how much stronger the changed words look than the line they sit on, and the shade follows
  from it.
- **A tab in the middle of a changed line no longer pushes the rest of the line out of line.** Where a
  line was drawn in pieces, a tab in a later piece counted from the start of that piece instead of
  the start of the line, so the code after it sat at the wrong column against the numbers beside it.

### 0.4.1 — 2026-08-27
- **Your Mac is remembered, so you pair with it once and never again.** Tapping a Mac you have
  already paired with opens its worktrees straight away — no QR code, no six words. Until now the
  pairing was written down and never read back, so every single time you opened the app it asked for
  a code for a Mac it had been paired with all along.
- **Nothing is stored that would go stale.** Where the Mac is gets looked up fresh every time you
  come back to it, because macOS picks a new port each time Granita starts there. What is kept is the
  token and your Mac's key, so the connection is pinned to that machine and refuses to reach any
  other — exactly as it was the moment you paired.
- **A Mac that revokes this phone stops pretending.** Press Revoke in your Mac's Devices tab and the
  phone forgets the pairing on its next read, so the Mac's row offers you the QR and the six words
  again instead of a list that can only fail.

### 0.4.0 — 2026-08-27
- **A file you have marked as read now shuts itself.** It becomes a single bar with its name, its
  numbers and the reason it is shut, and the diff you have already been through stops taking up the
  scroll. Tap the bar to open it again; tap the chevron in a file's header to shut one by hand.
- **Every shut file says why it is shut**, which is the point of the bar: *viewed*, *binary · no diff
  to show*, *renamed from … · no content change*, or how many lines it has with *Load diff* beside
  them. A binary file and a rename that changed nothing have no chevron at all — there is nothing
  behind them to open.
- **A very large file is no longer fetched until you ask for it.** Over 500 lines of diff it arrives
  shut, so opening a forty-file worktree no longer spends its first seconds on the one file you were
  never going to read on a phone. Files you read in an earlier sitting are skipped the same way.
- **You can see the lines a diff left out.** Every hunk band now carries a control at its right-hand
  end for the code above it and the code below it, twenty lines a press, and the control disappears
  when there is nothing left in that direction.

### 0.3.2 — 2026-08-27
- **One unreadable file no longer hides a whole worktree.** A symlink pointing at a folder is
  something git refuses to hash, and it was taking the entire change set down with it — two of the
  worktrees on this Mac had one, so the phone could not list anything at all. Now only that file
  goes without, and everything around it reads normally.
- **Granita no longer blames your Mac for something the app did.** Opening a worktree while the list
  behind it was still loading cancelled that read, and the app reported it as *Could not read your
  Mac* — so pressing Back showed an error that had never happened. A read you interrupted now leaves
  the screen you were on.
- **Try Again looks like it is trying.** Reading a Mac with a lot of repositories takes a while, and
  the button used to leave the error on screen the whole time, which read as a button that does
  nothing.
- When a git command does fail, Granita's log now leads with what git said instead of burying it
  behind a list of file paths that pushed it off the end of the line.

### 0.3.1 — 2026-08-26
- **The six words on your Mac have a Copy button.** They are there for when the camera cannot do it —
  and until now getting them off the screen meant dragging a selection across six words in a 13pt
  monospaced line. It sits on the same line as the words, so the countdown underneath does not move.
- What it copies is the line exactly as the tab shows it, middle dots included, because that is what
  your phone accepts back. Nothing goes on the clipboard once a code has run out.

### 0.3.0 — 2026-08-26
- **There is a file list, and tapping a file jumps the diff to it.** Pull it up from the *N files*
  button in the toolbar and it stays up while you read: the diff keeps scrolling behind it, so you
  can walk a change set file by file without dismissing anything between them.
- **The list is a tree, folded the way a project view folds it.** A directory chain with one thing
  in it is one row rather than five, a closed directory carries the totals of everything inside it,
  and a crowded one arrives closed. Over three files, or when everything is in one directory, there
  is no tree at all — just the files, because a tree over four rows is ceremony.
- **You can switch it to full paths**, and it is the same list in the same order with a different
  label, so the toggle never loses your place.
- **You can mark a file as read**, from the circle at the end of its header in the diff. Nothing
  infers it: this app's one job is telling you whether you have read something, so it will only ever
  say so because you said so. The file list shows what is done, a folder gets a tick when everything
  under it is read, and a line at the bottom tells you when there is nothing left.
- **On iPad the file list is a column of its own**, permanently beside the code, which is where this
  reads like a review tool rather than a phone app.
- **When your Mac declines to serve a whole change set, the list says so** rather than offering a
  *Load more* that could not have worked.

### 0.2.0 — 2026-08-26
- **You can read the diffs.** Tapping a worktree used to open a screen that said the file list was
  not built yet. It now opens every changed file in one continuous scroll — the code, the line
  numbers, what was added and what was removed.
- **Long lines run off the edge and you scroll them sideways**, and the line numbers stay where they
  are while you do. Code is not reflowed to fit a phone, because a wrapped diff is a different shape
  from the file you are reading.
- **What actually changed on a line is carried by the text**, not by a second highlight: the words
  that changed stay at full strength and the rest of the line steps back, which works in the dark as
  well as in the light.
- **A conflicted file says so in its header** before you scroll into it, and the markers themselves
  get their own colour.
- Files load five ahead of where you are reading, so a worktree with forty changed files opens at
  once instead of after forty round trips — and nothing you have already scrolled past is ever
  fetched behind you, so the page never jumps under your thumb.

### 0.1.2 — 2026-08-26
- **Pairing no longer hangs.** It worked — the Mac issued a token every time — and the phone
  simply never left the spinner, so the only way out was to force-quit and try again with a code
  that had already been spent. Found on a real iPhone within ninety seconds of first use.
- **Nothing in Granita can spin forever any more.** Every step of pairing is bounded, and a step
  that stops answering now says so, says whether your code was used, and tells you what to do —
  which differs depending on whether the Mac is left holding a device record for you.

### 0.1.1 — 2026-08-25
- **The worktree list is titled with your Mac's name.** It said *Worktrees*, which is the one thing
  you already knew: you had just tapped a Mac to get there. If you have two Macs serving, the title
  is now the only thing on the screen that tells them apart.

### 0.1.0 — 2026-08-25
- **You can pair your phone with your Mac, and then read what an agent has been doing.** This is the
  first release that does the thing the product is for. Choose *Pair a device* in Granita's menu bar,
  point your phone's camera at the QR code, and the Mac's worktrees appear.
- **No camera, or the camera is the screen you are pairing from?** Type the six words under the QR
  instead. One field, and the phone shows you the words it understood in the same shape the Mac shows
  them, so you check its reading rather than proofread your own typing.
- **The two are not equally safe, and the screen says so rather than pretending.** The QR carries your
  Mac's key over a channel nobody on the network can write to. Typed words carry a code and nothing
  else, so that path trusts whichever Mac answers first — which is why the camera is offered first and
  why one line at the bottom of the words screen tells you to use them on a network you trust.
- **Declining the camera is not an error.** The screen offers you the six words, and the trip to
  Settings is the small button underneath, not the one thing on offer.
- **Every way pairing can fail says which end has the problem and whether your code was spent.** A Mac
  running an older Granita, a phone running an older one, too many attempts, a Mac that stopped
  answering, and the rare case where pairing worked but your phone could not save the key — that last
  one now retries saving rather than sending you back to the Mac.
- **On iPad the worktree list is a proper sidebar** with the diff column beside it, instead of one
  column stretched across the screen.

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
