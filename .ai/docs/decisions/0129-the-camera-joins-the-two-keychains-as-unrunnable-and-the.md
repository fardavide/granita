# The camera joins the two Keychains as unrunnable, and the scope is renamed a fourth time

`CaptureSessionCodeScanner` is 137 lines of `AVCaptureSession` configuration that a host test process
cannot execute one branch of: there is no camera, `AVCaptureDevice.default(for: .video)` answers nil,
and the configuration returns before it has performed any of itself. That is the bar the two Keychain
stores met — unrunnable by construction rather than merely untested — and the login item after them.

**The decidable part was taken out before the exemption was added**, which is what separates this from
a hiding place. Turning whatever a metadata object carries into a `ScannedCode` is a pure function; it
lives in `MachineReadableCode` and is tested against a nil string, an empty one, a stranger's QR and a
damaged Granita link. What stays behind is session configuration, one delegate AVFoundation calls, and
a lifecycle guard — no branch a reader could ever see the wrong side of.

**This one raises the number, and that is the test this file applies to every rescoping**, so it is
argued rather than asserted: without it the Unit row reads 92.7% and with it 95.0%. The 2.3 points are
not tests that were written; they are lines that stopped being counted. What justifies counting them
out is that no test of any kind that this repository can run — host, snapshot, or the `ui` target that
does not exist — could ever reach them, so their presence in a denominator makes the row answer a
question about a camera rather than about the code.

`host-reachable-no-system-services-no-screens-no-appkit-serial` becomes
`…-no-appkit-no-camera-serial`. The rename is the mechanism working rather than a tidy-up: it makes
the Unit and All rows **unjudged for one run** and rejoin on the next `main` run, so nothing is
compared across two different file sets. **A reviewer should read this slice's green Unit row as
unjudged rather than as held** — the two rows that are genuinely judged here are the Snapshot ones,
and they went up.

