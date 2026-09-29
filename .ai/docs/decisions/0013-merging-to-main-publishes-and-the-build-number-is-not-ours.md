# Merging to `main` publishes, and the build number is not ours to set

The Xcode Cloud workflow is live: every squash merge to `main` archives the phone app and delivers it
to TestFlight for internal testers. **A merge is a release**, so the changelog entry and
`MARKETING_VERSION` have to be right before a pull request goes green — a TestFlight build cannot be
un-published, and the only fix is another build. `[ci skip]` in a commit title suppresses the archive,
which is the escape hatch for a docs-only merge.

The workflow itself is **server-side state** on the App Store Connect app record. It cannot be
code-reviewed, diffed or restored from git, and only the App Store Connect API can read it — which
cannot bootstrap it either, because Apple requires the first configuration to happen in Xcode.app. So
a repository with no CI configuration for its most consequential pipeline is expected here rather
than missing.

`CURRENT_PROJECT_VERSION` is a placeholder that nothing should bump by hand.
`ci_scripts/ci_pre_xcodebuild.sh` writes Xcode Cloud's own monotonic run number into it at build
time, because App Store Connect refuses a build number that repeats within a release train — every
build sharing one `MARKETING_VERSION`. Build 1 shipped before that script was on `main`, so it
archived as `0.0.1 (1)`; the script landed immediately afterwards, which is why the second upload did
not collide.

One prompt during setup is worth recording because it looks like a misconfiguration and is not: Xcode
Cloud asks for the GitHub app to be installed on the **`apple` organisation**, listing every
transitive `apple/swift-*` dependency. That is impossible — only an organisation owner can install it
— and unnecessary, because those repositories are public and are cloned anonymously. Apple's app is
installed on `fardavide/granita` alone.

