# Both Mac apps go out by Developer ID, and the Hardened Runtime takes the camera on the way

The second half of [issue #73](https://github.com/fardavide/granita/issues/73), and the half that has
been open longest: `status.md` has listed *a second Xcode Cloud workflow for the Mac app, archiving
with Developer ID and notarising* since 0.0.x, and the Client's Mac destination arrived with no
delivery path at all.

**Nothing here chooses the route, because `SPEC.md` §2 already did.** Both Mac apps are unsandboxed —
the server because a sandboxed process cannot usefully exec `git` against arbitrary folders, and the
Client because it is the server's sibling and gains nothing from a sandbox it would have to argue for.
That puts both outside the Mac App Store, which is the same place Tower, Fork and GitUp ship from, and
it is why neither can go to TestFlight: **TestFlight for macOS requires an App Store-signed build.**
Developer ID plus notarisation is the only door left, and it was chosen rather than fallen into.

### What that costs, and it is not the signing

**Notarisation requires the Hardened Runtime. The Hardened Runtime denies AVCapture.** Not to
sandboxed apps — to every app, unless `com.apple.security.device.camera` says otherwise, and the
denial arrives as a capture session that produces no frames rather than as an error anything logs.

So the entitlement goes in with the setting, in the same commit, because the two are one decision
pulled apart by build configuration. **The reason this is worth writing down is when it would have
been found**: `make build` signs nothing, every snapshot photographs a still rather than a camera, and
`CaptureSessionCodeScanner` is in `UNREACHABLE_FILES` precisely because a host test process has no
camera. Not one gate this repository runs would have gone red. The first evidence would have been a
notarised build, on a Mac, with a viewfinder drawing nothing — which is the defect issue #73 removed
from that exact screen on the way in, re-entering through the door marked *distribution*.

**It is scoped by SDK rather than by configuration**, and that is deliberate: a signed Debug build
carries the Hardened Runtime too, so `make run-client-mac` is denied the camera in exactly the way a
notarised build would be. Scoping it to Release would have made the one build nobody runs before
shipping the only build that could show the fault.

### What the repository can own and what it cannot

The workflow itself is **server-side state on the App Store Connect app record** — it cannot be
code-reviewed, diffed, or restored from git, which the delivery decision above already records as a
cost of choosing Xcode Cloud. What the repository owns is everything a workflow *reads*: the shared
schemes, the archive configuration, `ci_scripts/ci_pre_xcodebuild.sh` — which is generic and needs no
change for a third workflow, since it rewrites versions by build setting and not per platform — and
the signing and entitlement settings above.

`LSApplicationCategoryType` joins them for the Client. The menu bar app has carried it since it
shipped and the reason is the same: notarised distribution wants it, and Finder shows it.

### The Developer ID certificate is still the gate

An Apple Development identity is a real signature, which is all the local network privacy trap needs,
and it is why both Mac apps have run locally for a year without one. **A Developer ID Application
certificate has never been issued for this account**, so nothing here has ever been notarised, and no
amount of workflow configuration changes that. It is the first step rather than the last.

