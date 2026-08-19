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

## 1. Hummingbird 2 — current, and NIOTS is reachable

Latest release is 2.26.0; there is no Hummingbird 3, so the spec's choice is current rather than
pinned to an old major. Resolving it pulls `swift-nio-transport-services` and
`swift-service-lifecycle` transitively, which are the two the design depends on: the former is what
makes `BindAddress.nwEndpoint` route through the listener bootstrap that listens and advertises
Bonjour in one operation, and the latter is what the server's start and stop cycle is built on.

Not yet exercised in code — the bind path and TLS options are M2/M3 work — but the packages resolve
and compile in this graph.

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

**A conflicted path diffs as a normal unified diff.** Confirmed on a real conflicted merge: the
output carries a `diff --git` header and inline `<<<<<<<` / `=======` / `>>>>>>>` markers, and no
`diff --cc` appears anywhere. The parser therefore needs no combined-diff support, as the spec says —
it tags those lines instead.

## 5. `MenuBarExtra` + `Settings` under `LSUIElement` — open

The spec is explicit that this is "implement and verify", not "check whether it works". It needs the
menu bar app to exist. **M3.**

## 6. Claude Code session transcript shape — open

Needs one real transcript read on this machine, with the finding recorded at the top of the parser.
**M2.**

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
