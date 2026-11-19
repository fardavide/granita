# Manual Developer ID signing preserves Cloud archive provenance

The Xcode Cloud managed Developer ID export repeatedly failed with an empty certificate lookup
and a 409 / 7460 creation conflict. The original Mac archive was still available. On November 16,
2026, Davide approved issuing a manual Developer ID Application certificate, signing and notarizing
that archive locally, and publishing 0.24.0 after verification. The same process published 0.25.2
on November 19 without a new certificate or a support request.

This partially supersedes the Cloud-only signing responsibility in decision 0240. Cloud remains
the app build source. An owner-authorized manual release may copy the app from the original Cloud
archive for the intended source commit, sign it with the existing Developer ID identity in the
owner's login keychain, notarize and staple it, then use the existing release publisher. This does
not authorize exporting the signing key or moving it into GitHub Actions.

Before signing, verify successful push-to-main CI for that exact commit, its release tag, the Cloud
run's source revision and Mac archive action, and the app's bundle identifier, marketing version,
build number, architectures and entitlements. A failed distribution export is distinct from an
invalid archive. The app and DMG must both pass notarization and stapled-ticket validation before
the release becomes public. Published tags and assets remain immutable.

The release client supplies a pinned CA bundle for App Store Connect and CDN HTTPS requests. This
addresses a Python installation with no configured default CA file while retaining certificate
and hostname verification and keeping the API token off the CDN. It does not repair Apple's
managed-signing state. Automatic Cloud export remains a separate unresolved account issue.

The reusable publication command and verified release evidence are in
[`../mac-releases.md`](../mac-releases.md).
