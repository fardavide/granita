# Worktree loading profile — 13 September 2026

The fresh five-project read spends nearly all its measured server time inside git subprocesses.
Change metadata and status checks dominate; enumerating the worktrees is a small part of this read.
No performance optimization is selected from the historical 122.7-second measurement.

## Dataset and command

An isolated JSON store enables the same five project directories currently enabled on this Mac:
BandLab Android, Aura, Granita, Oltre and Swiftly. It contains no paired-device credentials. The
profiler does not open an HTTP listener, advertise Bonjour or create a server identity.

```sh
make run ARGS='--store /private/tmp/granita-loading-82-profile/granita.json --profile-worktrees'
```

The command reads the real worktree registry and measures the actual git client around each
subprocess. Server duration covers the whole registry read, including work outside git.

| Measurement | First read | Read with operation breakdown |
|---|---:|---:|
| Enabled projects | 5 | 5 |
| Returned worktrees | 10 | 10 |
| Changed files | 160 | 154 |
| Server processing | 5.585499167 s | 5.842867875 s |
| Git subprocess time | 5.567997163 s | 5.827623793 s |
| Status | 1.995744457 s / 10 calls | 2.153478792 s / 10 calls |
| Content hashes | 0.092367833 s / 4 calls | 0.088491209 s / 4 calls |
| Enumeration | included in other below | 0.054459250 s / 5 calls |
| Revision | included in other below | 0.093317668 s / 10 calls |
| Change metadata | included in other below | 3.437876874 s / 30 calls |
| Other git operations | 3.479884873 s / 45 calls | none |

All measured git calls succeeded. No diff-content subprocess ran for this endpoint. Working copies
were active between the reads, so their changed-file totals differ; these are observations, not a
controlled comparison of file volume. Both reads put more than 99% of server duration in git.
The second attributes about 59% to change metadata and 37% to status. It does not isolate the
independent effects of worktree count and changed-file count.

## Connection baseline

A separate fresh request reached the running Mac app's `https://127.0.0.1:8737/v1/health`. Curl
verified the existing certificate obtained read-only from this Mac's Keychain, without disabling
certificate checks. The endpoint returned HTTP 200 and certificate verification returned zero.

| Measurement | Duration |
|---|---:|
| TCP connection | 0.000217 s |
| Connection through completed verified TLS handshake | 0.010432 s |
| First response byte | 0.011626 s |
| Entire health response | 0.011686 s |

This is a loopback HTTPS baseline. It includes neither Bonjour discovery nor a remote Tailscale
round trip and cannot establish the phone's connection latency. The worktree profiler explicitly
prints the same scope limitation; the phone's Copy Logs retains actual route and HTTP timings.

## Consequence

The UI reports finding, pinned verification and waiting for the response separately. Its elapsed
clock spans the attempt and offers diagnostics after ten seconds. It does not convert this profile
into a percentage, an ETA or an invented server counter. Any later performance change should first
target and remeasure the status/change-metadata work rather than optimize enumeration or assume
the historical ten-repository measurement still represents the current dataset.
