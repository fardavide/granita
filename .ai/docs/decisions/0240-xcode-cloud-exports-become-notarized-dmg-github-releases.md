# Xcode Cloud exports become notarized DMG downloads on GitHub

Davide asked for Mac DMG downloads and GitHub releases. Xcode Cloud keeps the responsibilities
chosen in decision 0004: app archives, automatic Developer ID signing and app notarization.
GitHub Actions handles the public download after successful main CI, selecting the stapled
notarized Cloud artifact for exactly that source commit.

The extra App Store Connect team key is for authenticated artifact retrieval and DMG notarization.
It does not move a signing certificate or provisioning profile into GitHub. Rebuilding the app in
GitHub would duplicate the existing delivery route and require exporting Apple signing material;
publishing from `ci_post_xcodebuild.sh` would run before Cloud's notarization post-action finishes.
Polling the completed Cloud build avoids both.

Each app marketing version has one immutable public tag and downloads. New versions publish
automatically; unchanged published versions are skipped. Manual retry preserves the CI and commit
checks and can finish an incomplete draft. Assets are uploaded before the draft becomes public,
and neither an unnotarized Cloud export nor a rejected DMG can create a public release.

Publication reuses Davide's existing general GitHub CLI OAuth credential with `repo` and `workflow`
scopes, stored as `MAC_RELEASE_GITHUB_TOKEN` with his authorization. No duplicate token is created.
GitHub requires workflow access when tagging an older workflow-changing commit after main advances;
its built-in token cannot grant it. CI verification retains the built-in read token, and only
credential validation and publication receive the release credential.

The existing Default Cloud workflow was verified: it already archives the unified Mac scheme and
notarizes its export. Build 172 succeeded for the current main commit. Apple API access was enabled
with Davide's agreement; no team keys existed, so one generic `CI Automation` Developer key was
created. Artifact retrieval and notarization authentication succeeded with it. All four GitHub
secrets and the workflow ID variable are configured. The workflow still needs to land, and its
first DMG installation remains pending. The activation steps and permissions are recorded in
[`../mac-releases.md`](../mac-releases.md).
