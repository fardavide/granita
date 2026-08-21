# Verification

What the spec's verify-first pass (§14) actually found when run against this machine and this CI
runner, rather than against documentation.

The headline: **every trap in the spec reproduces.** The spec was written against git 2.43; it holds
on 2.52.0 locally and 2.55.0 on the runner. Nothing in it needed correcting.

Items that need code that does not exist yet are listed at the bottom as still open, with the
milestone that will close them. Anything measured is recorded with its number.

## Environment

| | |
|---|---|
| macOS | 26.5.1 |
| Xcode | 26.6, pinned on CI by a composite action |
| Swift | 6.3.3 |
| git, local | 2.52.0 |
| git, CI runner | 2.55.0 |
| XcodeGen | 2.46.0 |

## 1. Hummingbird 2 — current, and the Bonjour bind works end to end

Latest release is 2.26.0; there is no Hummingbird 3, so the spec's choice is current rather than
pinned to an old major.

**The §8 bind is real and was run.** `BindAddress.nwEndpoint` exists, and `Server.makeServer` routes
it through `NIOTSListenerBootstrap.bind(endpoint:)` — it `preconditionFailure`s rather than
degrading if handed a plain socket bootstrap, so running on a `NIOTSEventLoopGroup` is mandatory
rather than advisory. `NIOTSListenerBootstrap(validatingGroup:)` is how the group is checked.

Verified by running `granita-server` and browsing for it:

```
dns-sd -B _granita._tcp local
  Add  3   1 local.  _granita._tcp.  Granita Skeleton Test
  Add  2  14 local.  _granita._tcp.  Granita Skeleton Test

dns-sd -L "Granita Skeleton Test" _granita._tcp local
  … can be reached at MacBook-Pro.local.:59144

curl http://127.0.0.1:59144/v1/health
  {"apiVersion":1,"serverVersion":"0.0.1","name":"Granita"}
```

So the whole point of the trap holds: one object binds and advertises, and **the advertised port is
the one actually serving**. A separate `NWListener` would have bound the port itself, and two objects
cannot bind the same TCP port.

**One consequence the spec does not mention.** With a service endpoint the *system* chooses the port
— 59144 above, not 8737. SPEC §9's "port 8737, automatic fallback if taken, chosen port persisted"
therefore describes the `--insecure-http` path only; in the advertised path there is no port to
choose or persist. That costs nothing, because §10 already requires the client to re-resolve through
Bonjour before falling back to a stored address.

TLS options ride the same code path and are still unexercised. **M3.**

### The one dependency this forced

`swift-nio-transport-services` is now declared explicitly. It is **not** a fourth dependency in
substance: it was already in the resolved graph via Hummingbird, and SPEC §8 mandates its use.
SwiftPM simply requires a product be named before a target may import it, and Hummingbird does not
re-export it. `HummingbirdTesting`, used by the API tests, is a product of the Hummingbird package
itself and adds nothing.

## 2. swift-subprocess — 1.0.0, stable

The spec assumed it was usable; it has since reached 1.0.0. It compiles in a Swift 6 language mode
target under complete strict concurrency with no warnings.

## 3. Highlightr — 2.3.0, current

Still maintained, contrary to the abandonment risk that made the spec argue against the alternative.
**Throughput is unmeasured**: the spec asks for a p95 over a 200-line Swift block on device, and
there is no device build to measure on yet. Deferred to M5, where the number decides whether
highlighting needs a file-size cap.

## 4. git — every layout confirmed, twice

Confirmed by running the commands, on both git versions. The fixture generator asserts each of these
on every CI run, so a future regression is a red build rather than a silent misparse.

**`--no-ext-diff` and `--no-color` are not universal flags.**

```
git status --porcelain=v2 --no-ext-diff       → error: unknown option `no-ext-diff'
git worktree list --porcelain --no-ext-diff   → error: unknown option `no-ext-diff'
git rev-parse --no-color --show-toplevel      → prints "--no-color" as an output line, exit 0
```

The `rev-parse` case is the dangerous one and it behaves exactly as the spec warns: it does not fail,
it emits an extra line, so a parser reading the first line of `--show-toplevel` gets `--no-color` as
the repository root.

**The two `-z` rename layouts have opposite path orders.** Both confirmed by dumping raw bytes:

```
diff HEAD -z -M --numstat    1 \t 1 \t \0 o l d . t x t \0 n e w . t x t \0
                             ^ empty field, then OLD, then NEW

status --porcelain=v2 -z     2   R M   N . . .   … R100   n e w . t x t \0 o l d . t x t \0
                                                          ^ NEW first
```

`diff HEAD -z -M --raw` follows the numstat order — old then new — which the spec does not state
explicitly and which is worth knowing, since it is the command the tracked change set comes from.

**`git diff --no-index` exits 1 when files differ.** That is success, and the generator fails loudly
if it ever stops being 1.

**Unborn HEAD behaves as described.** `rev-parse --verify --quiet HEAD` exits 1, `diff HEAD` exits
128 with `fatal: ambiguous argument 'HEAD'`, and substituting the empty tree object
`4b825dc642cb6eb9a060e54bf8d69288fbee4904` produces the correct full-addition diff.

**Two configuration keys the spec does not name change what `status --porcelain=v2` reports**, and
its bytes are the worktree's revision. `status.showUntrackedFiles=no` empties the untracked section
outright. And with the collapsed default, adding a **second** file inside an already-untracked
directory leaves the output byte for byte identical — the directory was already one `?` line and
stays one — so a revision hashed from it does not move and the phone never learns anything
appeared. Reproduced on 2.52.0; `--untracked-files=all` is pinned because of it.

**A nested worktree is an untracked directory.** `ls-files --others` does not descend into another
repository; it emits one entry with a trailing separator. Since Claude Code puts its worktrees under
`.claude/worktrees/`, every project an agent has touched has one — and `hash-object --stdin-paths`
refuses it, failing the **whole batch** rather than that line. Found by running the server against
the fixture repository, not by reading anything.

**An unborn HEAD is reported as forty zeroes by `worktree list --porcelain`**, on a line present
like any other, so checking whether the line exists says a repository with no commits has one.

**A conflicted path diffs as a normal unified diff.** Confirmed on a real conflicted merge: the
output carries a `diff --git` header and inline `<<<<<<<` / `=======` / `>>>>>>>` markers, and no
`diff --cc` appears anywhere. The parser therefore needs no combined-diff support, as the spec says —
it tags those lines instead.

## 5. `MenuBarExtra` + `Settings` under `LSUIElement` — done, and it needs all of the pattern

Implemented and run on macOS 26, not looked up. The pattern SPEC §9 prescribes works as written: a
1×1 `Window` declared **before** the `Settings` scene holds `openSettings`, the menu records that
Settings was asked for rather than opening it, and the app switches to `.regular` and activates
before the call.

Measured on a build launched by `make run-mac`, driving the real status item through the
accessibility API rather than by hand:

```
before opening      background only = true         ← .accessory, no Dock icon
menu items          "Serving on MacBook-Pro.local:53613" / "Settings…" / "Quit Granita"
after clicking      background only = false        ← .regular, window on screen
```

**The 1×1 window is 1×33, and it is visible.** SwiftUI gives it a title bar, so what lands on screen
is a sliver. It cannot be closed — the render tree it holds is the whole point — so it is made
transparent and deaf to the mouse instead. Confirmed as `alpha=0.0` in `CGWindowListCopyWindowInfo`.

**TRAP, for anyone verifying a window this way: Stage Manager lies to window enumeration.** With
Stage Manager on, the Settings window reported 72×109 at the left screen edge through both
`CGWindowListCopyWindowInfo` and `screencapture -l`, while the window's own autosaved frame was
560×488 — because what was being measured was its **thumbnail in the Stage Manager strip**, under
the app's own name and flagged on-screen. Accessibility reported the process as having no windows at
all, for the same reason. Two hypotheses were chased and discarded against those numbers — a window
sizing to its tab bar, and one born miniaturised — before Davide said what was actually on his
screen. **Window geometry is not verifiable from outside the app on a Mac using Stage Manager.**

## 6. Claude Code session transcript shape — done, and the spec was wrong twice

Read on 2026-08-21 against `~/.claude/projects`: 117 session transcripts, largest **74 MB**, which
is what the head-and-tail rule exists for. The findings are recorded at the top of the parser, as
§7 asks, and two of them contradict §7:

- **`cwd` is not on every record.** It is on `user`, `assistant`, `attachment` and `system`, and on
  none of `queue-operation`, `last-prompt`, `pr-link`, `custom-title`, `atis-latch` or
  `bridge-session` — and one of those is frequently the first line of a file.
- **There is no `summary` record.** Zero across 400 files, against 4,468 `custom-title` and 10,023
  `last-prompt`. `custom-title` is the analogue.

One thing §7 got right and is worth keeping: `projects/*/*.jsonl`, exactly one level down. Below the
sessions sit 1,237 subagent transcripts sharing their session's `cwd`.

## 6b. Local network privacy on macOS, and Bonjour from inside the app — done

SPEC §8 warns that local network privacy exists on macOS 15+ and covers **registering** a service,
not only browsing. `GranitaMac` carries `NSLocalNetworkUsageDescription` and `NSBonjourServices`,
and a signed local build registers successfully — no alert blocked it on this Mac, which has
already granted Granita access. A machine granting it for the first time still gets the alert.

Confirmed against the running menu bar app rather than the executable:

```
lsof -p <pid>        Granita … TCP *:53611 (LISTEN)
dns-sd -B            _granita._tcp.  "MacBook Pro"
dns-sd -L            MacBook\032Pro._granita._tcp.local. → MacBook-Pro.local.:53611
curl /v1/health      {"serverVersion":"0.0.4","name":"Granita","apiVersion":1}
curl /v1/projects    401
```

So the advertised port is the port serving, inside the app and not only in the executable.

**TRAP, and it cost the first run: `ProcessInfo.processInfo.hostName` and
`Host.current().localizedName` are reverse DNS lookups, not names of this machine.** They answered
`customer.mlnnita1.isp.starlink.com` — the ISP's name for the public address — so Granita advertised
under a name nobody would recognise in a list of Macs, while the same call from a terminal a minute
later answered `macbook-pro.local` and looked fine. `SCDynamicStoreCopyComputerName` and
`SCDynamicStoreCopyLocalHostName` answer from the machine's own preferences and do not vary with
what the router says.

**A channel bound to a network endpoint has no `localAddress`.** `Application`'s `onServerRunning`
hands over a channel whose `localAddress` is `nil` under `BindAddress.nwEndpoint`, because there is
no POSIX socket beneath it — a status line built from it says the server is up and nowhere. The port
is on the `NWListener`, reachable through `NIOTSChannelOptions.listener`, which is also the object
that chose it.

## 7. XcodeGen — confirmed working for this shape

One project, a macOS target and a universal iOS/iPadOS target, both consuming a local package.
Verified as facts from commands, not from the YAML parsing:

- `xcodebuild -describeAllArchivableProducts -json` lists both apps with the right bundle
  identifiers, the right team, and a resolved icon path for the Mac app — which is the probe Xcode
  Cloud itself uses, and an empty array there is how a missing shared scheme presents.
- Both shared schemes are emitted, because `project.yml` declares a `schemes:` block. Without one
  XcodeGen emits none, silently.
- Regeneration is **byte-stable**: two runs produce an identical `project.pbxproj`, so committing the
  project does not churn the diff.
- Both apps build clean with zero warnings.

One correction to the shape inherited from Oltre: `UIRequiresFullScreen` is deprecated as of iOS 26
and will be ignored, so declaring it only produces a build warning. Oltre targets iOS 16, where it
still does something. It is deliberately absent here.

## 8. ATS with a pinned self-signed identity — open

Needs the pairing path on a device. **M4.**

## 9. Character-wrapping height arithmetic — open

Needs a text rendering path to measure against. The parser side of it — the display-column count per
line — is M1, and a fixture line with tabs, wide characters, a combining mark and a 400-character run
is already in the corpus waiting for it. **M5.**

## 10. CI runner image — confirmed

`macos-26` carries Xcode 26.6, so the pinned selection succeeds rather than falling back with a
warning. All four jobs pass. The iOS build targets a generic simulator destination and needs no
specific runtime installed, so `xcodebuild -downloadPlatform iOS` is not required; a snapshot job
against a named simulator will need the availability probe Aura uses, and that lands with it.

## 11. Xcode Cloud, proven as far as signing

The repo-side work is done and an **unsigned archive of the phone app succeeds**. Inspected rather
than trusted, on the archived product:

| | |
|---|---|
| `CFBundleIdentifier` | `dev.fardavide.granita.mobile` |
| `CFBundleShortVersionString` | `0.0.1`, from `project.yml` |
| `MinimumOSVersion` | `26.0` |
| `ITSAppUsesNonExemptEncryption` | `false` — without it every build sits in "Missing Compliance" |
| icon | `Assets.car` + `AppIcon*.png` present; `CFBundleIconName` nested under `CFBundleIcons` |
| `Frameworks/` | absent — the package is linked, not embedded, so no ITMS-90171 |
| architecture | `arm64` |

`ci_scripts/ci_pre_xcodebuild.sh` is committed with its executable bit (`100755`) and was dry-run
the way Xcode Cloud calls it: `CI_BUILD_NUMBER=42` rewrote `CURRENT_PROJECT_VERSION` across all four
build configurations and re-pinned `MARKETING_VERSION` from `project.yml`.

### `UIDeviceFamily` is present — and how a check destroyed the evidence

`UIDeviceFamily` is `[1, 2]` in the unsigned archive, so iPad support — a LOCKED v1 requirement — is
intact. `TARGETED_DEVICE_FAMILY` resolves to `1,2` for the Release/device configuration and the
simulator and plain device builds agree.

An earlier revision of this file claimed the opposite, and the cause is worth keeping because it will
bite again: **`plutil -extract <key> <format> <file>` rewrites the file in place.** Without `-o -`
it does not print to stdout; it replaces the plist with the extracted value. The check ran, silently
truncated `Info.plist` from 1729 bytes to a 5-byte array, and every inspection afterwards saw a plist
with no keys — which read exactly like "the key is missing".

Reproduced deliberately:

```
before                                  1729 bytes
plutil -extract UIDeviceFamily json …      5 bytes   ← the file, not stdout
```

**Inspect a plist with `plutil -p <file>`, which is read-only.** Use `plutil -extract` only with an
explicit `-o -`. The same applies to anything else that inspects a build product: a check that
mutates what it measures produces a finding about itself.

Everything past signing is unproven until the first Xcode Cloud run.

## 12. The walking skeleton, on real hardware

Confirmed on 2026-08-19, end to end, with nothing simulated:

```
Mac    granita-server advertising _granita._tcp as "Davide's MacBook Pro"
       dns-sd -L → MacBook-Pro.local.:59145
       curl      → {"name":"Granita","serverVersion":"0.0.2","apiVersion":1}

phone  Granita 0.0.2, installed from TestFlight, lists "Davide's MacBook Pro"
```

What that closes, none of which was inferred:

- **Delivery.** Merge to `main` → Xcode Cloud archive → TestFlight → an installed app. Signing,
  provisioning, the icon and the version keys all real.
- **Discovery on device.** `NWBrowser` finds the service, and the local network permission prompt
  appears and works. Neither is observable in the simulator.
- **mDNS across segments.** The Mac was on Ethernet and the phone on Wi-Fi, so that network bridges
  multicast DNS between them. Worth knowing, because a router that does not would look exactly like
  a bug in the app.

**Still unverified: the refused path.** `localNetworkDenied` is covered by a test through a fake, but
nobody has watched iOS actually withhold the permission. That state exists precisely because a denied
browser is indistinguishable from one finding nothing, so it is the one worth seeing for real.
