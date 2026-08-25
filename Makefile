# Granita — the sanctioned way to build, test and run this project.
#
# Every target here is the real invocation, verified green in CI. If one of them fails, that
# failure is the problem to solve; reaching past it to a raw xcodebuild is how a change lands
# without following the project's rules.

PACKAGE      := Packages/Granita
PROJECT      := Granita.xcodeproj
IOS_SIM      := platform=iOS Simulator,name=iPhone 17,OS=latest
IOS_GENERIC  := generic/platform=iOS Simulator
MAC_GENERIC  := generic/platform=macOS
UNSIGNED     := CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
# Generated and committed, and therefore checkable. The icons are generated and committed too but
# are deliberately absent — see verify-generated.
GENERATED    := $(PROJECT) $(PACKAGE)/Core/Diff/DomainTests/Fixtures
# Recorded, not generated: no source produces them, so verify-generated cannot check them and the
# snapshot job is what gates them instead.
# The phone's only. The Mac's baselines are recorded on the CI runner and adopted with
# Scripts/adopt-mac-baselines.py — re-recording them locally is what turns CI red, so
# `record-snapshots` deliberately cannot reach them.
SNAPSHOTS    := Apps/GranitaMobileSnapshotTests/__Snapshots__

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | awk -F':.*?## ' '{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

.PHONY: project
project: ## Regenerate Granita.xcodeproj from project.yml
	xcodegen generate

.PHONY: test
test: ## Run the package test suite — no simulator, no Xcode
	cd $(PACKAGE) && swift test

.PHONY: build
build: ## Compile-check the package and both apps
	cd $(PACKAGE) && swift build
	xcodebuild build -project $(PROJECT) -scheme GranitaMac    -destination '$(MAC_GENERIC)' -quiet $(UNSIGNED)
	xcodebuild build -project $(PROJECT) -scheme GranitaMobile -destination '$(IOS_GENERIC)' -quiet $(UNSIGNED)

.PHONY: coverage
coverage: ## Run the coverage gate locally — CI's verdict on five of the six values
	@# **This exists so a falling row is found here rather than twenty minutes later.** The gate is a
	@# plain ratchet with no slack against the last `main` run, so any change that adds code can push
	@# a row under it — and every time that has been discovered from a red pull request instead of
	@# from here, the cost was a full CI round trip to learn a number that was already computable.
	@#
	@# It runs the same script CI runs and hands the result to the same predicates. **Five of the six
	@# values are therefore the verdict; `All tests` lines is not.** Measured on 25 August 2026 on a
	@# clean tree: it reads 12 lines below what the runner published for the same commit, because
	@# `all` merges the profiles of two app-hosted suites whose hosts start a real server and a real
	@# browser, and how far those get differs per machine. Read a fall in that one row against a
	@# clean-tree run of the same working copy — the uncovered line count printed under the table is
	@# stable across the difference. The `swift-testing` skill's coverage reference has the per-file
	@# measurement.
	@#
	@# **It is not fast** — three passes, one of which builds the iOS app and boots a simulator, and
	@# one of which renders the Mac's panes. Several minutes. That is the price of the answer, and it
	@# is a fraction of the round trip it replaces.
	@#
	@# A red run prints which rows fell and by how much. **Which FILES moved is the next question and
	@# this does not answer it** — for that, read build/coverage/{unit,snapshot,all}.json, which this
	@# leaves behind. A row that falls is read, never estimated: this repository has three recorded
	@# instances of algebra reaching the wrong conclusion about which file moved a number.
	Scripts/fetch-coverage-baseline.sh
	.github/scripts/measure-coverage.sh
	python3 .github/scripts/coverage.py render \
		--current build/coverage/summary.json \
		--baseline .coverage-baseline/summary.json \
		--out build/coverage/comment.md \
		--verdict-out build/coverage/verdict.json
	@cat build/coverage/comment.md
	@python3 .github/scripts/coverage.py enforce --verdict build/coverage/verdict.json

.PHONY: coverage-baseline
coverage-baseline: ## Re-fetch main's coverage numbers, discarding the cached copy
	Scripts/fetch-coverage-baseline.sh --force

.PHONY: run
run: ## Run the backend in a terminal, no Xcode in the loop — `make run ARGS="--pair"`
	@# ARGS is how every flag in `granita-server --help` is reached: --add-project, --pair,
	@# --issue-token, --insecure-http, --store. Without it the only way to pass one is a raw
	@# `swift run`, which is reaching past the sanctioned target rather than through it.
	cd $(PACKAGE) && swift run granita-server $(ARGS)

.PHONY: snapshots
snapshots: snapshots-ios ## Render the phone's screens and compare against the committed baselines
	@# The Mac's are not here, because they cannot pass on this machine. `make snapshots-mac` runs
	@# them and is expected to be red; see that target.

.PHONY: snapshots-ios
snapshots-ios: ## Render the phone's screens on a simulator
	xcodebuild test -project $(PROJECT) -scheme GranitaMobile -destination '$(IOS_SIM)' -quiet CODE_SIGNING_ALLOWED=NO

.PHONY: snapshots-mac
snapshots-mac: ## Render the Mac's Settings panes — EXPECTED TO FAIL locally, see the comment
	@# **A red run here is the normal state on a developer's Mac, and is not something to fix.**
	@# The committed baselines are the CI runner's renders, because a Retina laptop and a headless
	@# runner lay text out on different backing grids and the drift swamps a real change. What this
	@# target is good for locally is the diff report: it shows what moved, and the eye does the rest.
	@# The gate that matters is `Snapshot tests (macOS)` on the pull request.
	@# `-only-testing` because the scheme now holds two kinds. Without it this target would also
	@# drive the app, and a UI failure would surface in the job that photographs screens.
	xcodebuild test -project $(PROJECT) -scheme GranitaMac    -destination 'platform=macOS' -only-testing:GranitaMacSnapshotTests -quiet CODE_SIGNING_ALLOWED=NO

.PHONY: ui-tests-mac
ui-tests-mac: ## Drive the Mac app and assert what pressing things changed
	@# The kind that catches a dead control, which a baseline never can: it launches the real app
	@# against a store in a temporary directory and reads the document back.
	@#
	@# **Needs Accessibility permission on this machine and says nothing useful without it** — the
	@# failure is "The test runner failed to initialize for UI testing. (Timed out while enabling
	@# automation mode.)", which names no setting. Grant the terminal or Xcode under System
	@# Settings › Privacy & Security › Accessibility. Nothing in CI runs this target yet.
	@#
	@# **Signed, unlike every other test target here, and that is not a preference.** A UI test
	@# bundle is a separate runner app that has to launch and drive another process; unsigned it
	@# is killed before it can connect, and the only thing xcodebuild says is `Test crashed with
	@# signal kill before establishing connection`, which names nothing. So no
	@# CODE_SIGNING_ALLOWED=NO here.
	xcodebuild test -project $(PROJECT) -scheme GranitaMac    -destination 'platform=macOS' -only-testing:GranitaMacUiTests -derivedDataPath .build/mac-ui -quiet

.PHONY: record-snapshots
record-snapshots: ## Re-record every snapshot baseline after a deliberate design change
	@# The recording procedure, and the second run is the point of it. snapshot-testing writes a
	@# missing baseline and fails that same run, so a single pass can only tell you it wrote
	@# something — never that what it wrote renders stably. The re-run compares, and a red one here
	@# means the screen is not deterministic rather than that the design moved.
	@#
	@# Never run this on CI. A recorder on CI turns the suite into a record of whatever the code
	@# currently does, which is a test that cannot fail.
	@# The phone's only, and the Mac's absence here is deliberate rather than an omission. Its
	@# baselines are the CI runner's renders: a Retina laptop lays text out on a 2x grid and a
	@# headless runner on a 1x one, and the resulting drift is four and a half times larger than a
	@# real one-word copy change, so no tolerance separates them. Re-recording the Mac locally makes
	@# `make snapshots-mac` green here and `Snapshot tests (macOS)` red on every pull request.
	@# See Scripts/adopt-mac-baselines.py.
	rm -rf $(SNAPSHOTS)
	-@$(MAKE) --no-print-directory snapshots-ios
	@$(MAKE) --no-print-directory snapshots-ios
	@echo "Phone baselines re-recorded and verified stable. Review every changed PNG before committing."

.PHONY: run-mac
run-mac: ## Build and launch the menu bar app, signed for this machine
	@# Signed and Debug, unlike `make build`. macOS 15+ tracks program identity by code signature
	@# for local network privacy, so an unsigned build cannot register a Bonjour service at all —
	@# which is most of what there is to see here.
	xcodebuild build -project $(PROJECT) -scheme GranitaMac -configuration Debug \
		-destination 'platform=macOS' -derivedDataPath .build/mac -quiet
	open .build/mac/Build/Products/Debug/Granita.app

.PHONY: fixtures
fixtures: ## Rebuild the git fixture repositories and the golden diff fixtures
	./Scripts/make-fixture-repo.sh

.PHONY: icons
icons: ## Regenerate both app icon sets from Art/icon/*.svg
	./Scripts/make-app-icons.py

.PHONY: verify-generated
verify-generated: ## Fail if the committed project or fixtures are stale versus their sources
	@# Icons are deliberately not checked here. Their PNGs are committed, but rasterising an SVG is
	@# not reproducible across machines or OS releases, so this would compare a runner's
	@# antialiasing against a laptop's and fail on artwork nobody touched. `make icons` is manual.
	@$(MAKE) --no-print-directory project fixtures
	@# Regenerate from a differently-named directory. Anything that leaks the build location into a
	@# committed fixture — an absolute path, or a tracked file containing one, which changes every
	@# commit hash downstream of it — shows up here rather than on a runner whose checkout lives
	@# somewhere else. Two runs in the same directory cannot catch this class of bug.
	@./Scripts/make-fixture-repo.sh --out "$$(mktemp -d)/granita-path-independence-check" > /dev/null
	@# Scoped to the generated paths, not the whole tree: this asks "is what is committed what the
	@# sources produce", which is a different question from "are there uncommitted edits". Checking
	@# the whole tree would make the target unusable locally mid-change.
	@if [ -n "$$(git status --porcelain -- $(GENERATED))" ]; then \
		echo "::error::Generated files are stale. Run 'make project fixtures' and commit the result."; \
		git status --porcelain -- $(GENERATED); \
		git --no-pager diff --stat -- $(GENERATED); \
		exit 1; \
	fi
	@echo "Generated files are in sync with their sources."

.PHONY: clean
clean: ## Remove build output and the generated fixture repositories
	rm -rf $(PACKAGE)/.build .fixtures
	xcodebuild clean -project $(PROJECT) -scheme GranitaMac    -quiet || true
	xcodebuild clean -project $(PROJECT) -scheme GranitaMobile -quiet || true

.PHONY: resolve
resolve: ## Refresh Package.resolved for the Xcode graph (run before committing after `swift test`)
	@# Xcode resolves the project AND the local package as one graph and writes the union here;
	@# `swift build` and `swift test` rewrite the same file with the package's own dependencies
	@# only, dropping the Xcode-only ones. Xcode Cloud disables automatic resolution and refuses a
	@# stale file, so the union is what must be committed.
	@# Into a throwaway derived data path, deliberately. With a warm one there is nothing to
	@# resolve, so xcodebuild does not rewrite the file and silently leaves whatever `swift build`
	@# last wrote — which is the stripped version this target exists to undo.
	xcodebuild -resolvePackageDependencies -project $(PROJECT) -scheme GranitaMobile \
		-derivedDataPath "$$(mktemp -d)/resolve" > /dev/null
	@python3 -c "import json;d=json.load(open('$(PACKAGE)/Package.resolved'));\
		pins=d['pins'];\
		ok=any('snapshot' in p['identity'] for p in pins);\
		print(f\"Package.resolved: {len(pins)} pins, Xcode graph {'covered' if ok else 'MISSING'}\");\
		exit(0 if ok else 1)"
