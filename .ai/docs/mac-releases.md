# Mac downloads and GitHub releases

Xcode Cloud builds, signs and notarizes the unified `GranitaMac` app. GitHub Actions waits for the
notarized export of the same commit, puts `Granita.app` beside an Applications shortcut in a
compressed DMG, notarizes and staples the DMG, and publishes it on
[GitHub Releases](https://github.com/fardavide/granita/releases). The release carries
`Granita-<version>.dmg`, `SHA256SUMS`, and the matching entry from `CHANGELOG.md`.

The GitHub workflow starts after a successful **push-to-main CI run**. It never builds or signs the
app itself, never consumes PR artifacts, and never uploads an unnotarized export. A separate token
writes tags and releases; Apple signing certificates and profiles stay in Xcode Cloud.

## One-time activation

The repository contains the workflow and tests. `MAC_RELEASE_GITHUB_TOKEN` is configured by reusing
Davide's existing general GitHub CLI credential; no additional GitHub token was created. Apple API
access was enabled with his approval, and the account had no existing team API keys. The generic
`CI Automation` team key was created with Developer access. Its Cloud artifact access and
`notarytool` authentication were verified before configuring the three Apple secrets and workflow
ID. All four secret names and the workflow variable were verified in GitHub on 2026-10-05.

The existing [Default Cloud workflow](https://appstoreconnect.apple.com/teams/eda2fc58-4dc8-4f98-9df3-b49523602902/xcode-cloud/products/D317DECF-1450-4D33-A3C9-16D22414AEFA/workflows/6C5E31FF-C253-4A3C-ACAF-DD9942472336)
already archives `GranitaMac` and `GranitaMobile` on main changes, using Xcode 27. Its Mac archive
has Distribution Preparation **None** and a **Notarize - macOS** post-action; its mobile archive
has internal TestFlight distribution. Build 172 completed successfully at commit
`3998b27b74a14124dd46b984a7b0b439023c692a` and exposes one stapled notarized Mac artifact. The workflow
was reused without changes. The steps below describe the configuration for future maintenance.

The production export passed the release code's bundle identity, version/build, Developer ID team
signature and stapled-ticket checks. A validation DMG from build 172 was accepted by Apple's
notarization service, stapled, and passed both ticket and disk-image verification. This validation
did not create a GitHub tag or release. The first published-download installation remains to be
checked after the workflow lands.

The reusable team key is `CI Automation` (`5688H8P87Y`), with issuer
`eda2fc58-4dc8-4f98-9df3-b49523602902`. Its one-time download was moved into Davide's existing private
`Documents/Keys` folder as `AuthKey_5688H8P87Y.p8`, readable only by his account. The private material
is also encrypted in `ASC_PRIVATE_KEY`; it is never committed.

1. In [Apple Developer certificates](https://developer.apple.com/account/resources/certificates/list),
   ensure team `A7Q83J6LR4` has a **Developer ID Application** certificate available to Xcode Cloud.
   An Apple Development certificate does not qualify.
2. In [Xcode Cloud](https://appstoreconnect.apple.com/), verify the existing workflow archives the
   **GranitaMac** shared scheme in `Granita.xcodeproj`: Xcode 27, macOS, Release archive,
   Distribution Preparation **None**, and a **Notarize** post-action, which produces the Developer
   ID signed export. Start it on main-branch changes and allow manual
   builds for retry. Configure these settings only if missing. There is one unified Mac app; the
   mobile scheme is iOS/iPadOS only.
3. In [App Store Connect team API keys](https://appstoreconnect.apple.com/access/integrations/api),
   reuse an existing **team key** with access to Xcode Cloud build artifacts and notarization.
   Create one only if no suitable key and its private material are available. Developer
   access is the intended minimum; use App Manager only if required by the account's access
   policy. Individual keys do not support `notarytool`. Download its `.p8` once and retain it
   securely. Do not commit it.
4. Add three [GitHub Actions secrets](https://github.com/fardavide/granita/settings/secrets/actions):
   `ASC_ISSUER_ID`, `ASC_KEY_ID`, and `ASC_PRIVATE_KEY`. The last is the complete multiline `.p8`
   contents, including its BEGIN and END lines. The same team key reads Cloud artifacts and
   authenticates the DMG's `notarytool` submission.
5. Reuse an existing general GitHub credential for the Actions secret `MAC_RELEASE_GITHUB_TOKEN`.
   The configured GitHub CLI OAuth credential has `repo` and `workflow` scopes, and its reuse was
   authorized by Davide. A replacement fine-grained token needs **Contents: read and write** and
   **Workflows: read and write** for this repository. Replace the secret if the credential is revoked
   or expires; do not create a duplicate token merely for this workflow.
   GitHub can require both permissions when creating tags for historical commits that changed
   workflows. Main may advance while Cloud builds; the built-in `GITHUB_TOKEN` cannot grant
   Workflows write. Only credential validation and publication receive this token; CI
   verification uses the built-in read token. The workflow never edits a workflow file through
   the release token.
6. Find the Mac workflow's UUID through App Store Connect's `ciProducts` / `ciWorkflows` API or its
   Cloud workflow URL, and add the [Actions variable](https://github.com/fardavide/granita/settings/variables/actions)
   `XCODE_CLOUD_MAC_WORKFLOW_ID`. **Set this last:** a nonempty value activates automatic releases.
   Until then automatic release jobs are skipped, while a manual run explains missing setup.
7. Merge the workflow, let main CI and the Mac Cloud workflow finish, then verify that the first
   release has both assets. Mount the downloaded DMG, drag Granita to Applications and launch it
   on a Mac to verify Gatekeeper and installation with the real production signature.

Apple's workflow configuration and signing certificates remain account state and are verified
through authenticated Apple access. The temporary `.p8` on the runner is private and removed in
an always-run cleanup step; it is excluded from retained release artifacts.

## Version and retry rules

`project.yml` supplies `MARKETING_VERSION`; the exported app must agree and must carry the selected
Xcode Cloud build number. A missing changelog entry, failed Cloud build, absent notarized export,
wrong app identifier, wrong signing team, or rejected notarization blocks publication.

One marketing version maps to one `v<version>` release. Automatic runs skip an already published
version, including docs-only main changes. They never move its tag or replace published downloads.
A new downloadable build requires the usual version and changelog bump. This workflow change does
not change the app version or behavior.

After the DMG passes validation, publication fixes its exact commit with a lightweight version tag,
creates a draft against that existing tag, uploads both verified assets, then publishes the draft.
The release credential covers GitHub's permission check for historical tags. A tag may remain
if draft creation fails; retry uses it without moving it.
An upload failure leaves a recoverable draft, not a public release with missing downloads. A retry
can replace assets in that draft only when its target commit agrees. An existing tag for another
commit is refused. The workflow serializes retries of the same commit without canceling a running
publication, and different version commits can complete independently.

To retry, use **Run workflow** on [Mac release](https://github.com/fardavide/granita/actions/workflows/mac-release.yml)
with the workflow branch set to **main**. Supply the full main-branch commit SHA, or leave it blank
for current main. The commit must have a successful main push CI run and an available notarized
Cloud build. A failed or canceled Cloud build must first be rebuilt in Cloud; GitHub does not
silently use a different commit or an unsigned archive.

The wait for Cloud is bounded at one hour; DMG notarization waits up to thirty minutes. A longer
Cloud build can be retried after it completes. The workflow retains the DMG, checksum, changelog
notes and notarization diagnostics for fourteen days, including failures. Publication errors fail
the job and keep an incomplete release private.

## Local verification

```bash
make release-tests   # isolated release tests with command fakes; never publishes
make release-plan    # preview current version and changelog; never publishes
make coverage-tests  # all CI-tooling tests, including releases; existing CI runs this gate
```

The release tests verify source-commit selection, rejection of unnotarized exports and failed
builds, API pagination and signed JWTs, rejection before publication, draft recovery, matching
tags, and upload ordering. The app's package tests, unsigned build and existing CI coverage and
snapshot gates retain their separate jobs.

The publishing command is `make release-mac`, used by Actions after its main/CI gate. It requires
`ASC_ISSUER_ID`, `ASC_KEY_ID`, `RELEASE_KEY_FILE`, `GITHUB_REPOSITORY`, `RELEASE_REVISION`, and
`XCODE_CLOUD_MAC_WORKFLOW_ID`, plus `GH_TOKEN` containing the release credential. It has external
effects; use the preview and test commands to review
the setup before activating it.

## References

- [Apple: Xcode Cloud distribution and notarization](https://developer.apple.com/documentation/xcode/creating-a-workflow-that-builds-your-app-for-distribution)
- [Apple: build artifacts and temporary download URLs](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-ciartifacts-_id_)
- [Apple: customizing notarization](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
- [Apple: team and individual API keys](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api)
- [GitHub: workflow_run and token permissions](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_run)
- [GitHub: workflow scope when releases target unreferenced commits](https://github.blog/changelog/2023-11-02-github-actions-enforcing-workflow-scope-when-creating-a-release/)
- [GitHub: permissions for creating a tag reference](https://docs.github.com/en/rest/git/refs#create-a-reference)
