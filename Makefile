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

.PHONY: run
run: ## Run the backend in a terminal, no Xcode in the loop
	cd $(PACKAGE) && swift run granita-server

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
