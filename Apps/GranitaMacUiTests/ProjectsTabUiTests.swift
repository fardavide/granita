import XCTest

/// Projects, driven rather than photographed.
///
/// **This is the kind of test this project has owed since a dead control shipped for eight
/// releases.** The snapshot suite rendered that control in four layouts and stayed green throughout,
/// because a baseline photographs a button whether or not anything is behind it. What is asserted
/// here is the *effect*: press the thing, then read back something that could only have changed if
/// pressing it did something.
///
/// **XCTest rather than Swift Testing, and that is not a relaxation of the rule.** `XCUIApplication`
/// is XCTest-only — there is no Swift Testing equivalent — so the exception is exactly this bundle
/// and nothing else in the repository moves.
///
/// **The app is launched against a store in a temporary directory.** Without that this test would
/// drive the reader's own document on a real Mac and switch a real repository on, which is the one
/// thing this tab must never do by accident. `--store` is the same flag `granita-server` has taken
/// since M2.
final class ProjectsTabUiTests: XCTestCase {

    private var sandbox: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        sandbox = URL(filePath: NSTemporaryDirectory())
            .appending(path: "granita-ui-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: sandbox)
    }

    // MARK: - The harness itself

    /// The spike, and it is a test rather than a comment because everything below depends on it.
    ///
    /// Nothing in this repository had ever run an XCUITest when this was written, and whether a
    /// runner can drive an `LSUIElement` app under `xcodebuild test` was genuinely unknown. If this
    /// one fails, the others fail for a reason that has nothing to do with Projects.
    func testSettingsOpensWithoutAnybodyClickingTheStatusItem() throws {
        let app = launch(withProjects: [])

        // Granita has no window until its menu is opened, so `--open-settings` is what a test uses
        // instead of hunting a status item in the menu bar.
        let window = app.windows["Projects"].firstMatch
        XCTAssertTrue(
            window.waitForExistence(timeout: 30),
            "Settings did not open. Windows seen: \(app.windows.allElementsBoundByIndex.map(\.title))"
        )
    }

    // MARK: - What the controls actually do

    func testSwitchingAProjectOnMakesItReadableAndSurvivesReading() throws {
        let repository = try makeRepository(named: "granita-ui-test")
        let app = launch(withProjects: [repository])
        XCTAssertTrue(app.windows["Projects"].firstMatch.waitForExistence(timeout: 30))

        let toggle = app.descendants(matching: .any)["granita.projects.visible.\(repository.id)"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "no switch for the seeded project")
        XCTAssertEqual(toggle.value as? Int, 0, "a seeded project must arrive switched off")

        toggle.click()

        // The effect, read back from the document rather than from the screen. A row that redraws
        // itself while nothing is written is precisely the defect this kind of test exists for.
        expectStored(isVisible: true, forProjectAt: repository.path)
    }

    func testTheRemoveButtonIsInoperableUntilARowIsPicked() throws {
        let repository = try makeRepository(named: "granita-ui-test")
        let app = launch(withProjects: [repository])
        XCTAssertTrue(app.windows["Projects"].firstMatch.waitForExistence(timeout: 30))

        let remove = app.descendants(matching: .any)["granita.projects.remove"].firstMatch
        XCTAssertTrue(remove.waitForExistence(timeout: 10))
        XCTAssertFalse(remove.isEnabled, "the minus must not be operable with nothing selected")
    }

    // MARK: - The app under test

    private struct SeededProject {
        let id: String
        let name: String
        let path: String
    }

    private func launch(withProjects projects: [SeededProject]) -> XCUIApplication {
        let storeUrl = sandbox.appending(path: "granita.json", directoryHint: .notDirectory)
        // Written by hand rather than through the store, because a UI test's fixture has to be
        // readable in the test that depends on it — and because reaching the package's own types
        // from a UI test bundle would link the whole graph into the runner.
        let document = """
            {"schemaVersion":1,"projects":[\(projects.map(entry).joined(separator: ","))],\
            "worktrees":{},"viewed":{},"devices":[]}
            """
        try? Data(document.utf8).write(to: storeUrl)

        let app = XCUIApplication()
        app.launchArguments = ["--store", storeUrl.path(percentEncoded: false), "--open-settings"]
        app.launch()
        return app
    }

    private func entry(_ project: SeededProject) -> String {
        """
        {"id":"\(project.id)","path":"\(project.path)","name":"\(project.name)","isVisible":false}
        """
    }

    /// A real repository, because the row reads what is behind the folder and an empty directory is
    /// the "not a repository" state rather than the one being asserted. No commit is needed — an
    /// unborn `HEAD` is a case the worktree layer already handles.
    private func makeRepository(named name: String) throws -> SeededProject {
        let url = sandbox.appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let git = Process()
        git.executableURL = URL(filePath: "/usr/bin/git")
        git.arguments = ["init", "--quiet", url.path(percentEncoded: false)]
        try git.run()
        git.waitUntilExit()
        return SeededProject(id: name, name: name, path: url.path(percentEncoded: false))
    }

    private func expectStored(
        isVisible: Bool,
        forProjectAt path: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let storeUrl = sandbox.appending(path: "granita.json", directoryHint: .notDirectory)
        // The write is debounced and goes through an atomic replace, so it is read back until it
        // lands rather than once, immediately.
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            if let data = try? Data(contentsOf: storeUrl),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let projects = json["projects"] as? [[String: Any]],
               let project = projects.first(where: { $0["path"] as? String == path }),
               project["isVisible"] as? Bool == isVisible {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTFail("the document never recorded isVisible=\(isVisible) for \(path)", file: file, line: line)
    }
}
