import AppKit
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
    private var preferencesSuite: String!

    override func setUpWithError() throws {
        continueAfterFailure = false
        sandbox = URL(filePath: NSTemporaryDirectory())
            .appending(path: "granita-ui-\(UUID().uuidString)", directoryHint: .isDirectory)
        preferencesSuite = "dev.fardavide.granita.tests.\(sandbox.lastPathComponent)"
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        let app = XCUIApplication()
        if app.state != .notRunning { app.terminate() }
        try XCTUnwrap(UserDefaults(suiteName: preferencesSuite)).removePersistentDomain(forName: preferencesSuite)
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

    func testShowWorktreesOpensTheLocalReaderAndProjectsSettingsRegardlessOfServerState() throws {
        // given
        let app = launch(withProjects: [])
        let settings = app.windows["Projects"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 30))
        settings.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(settings.waitForNonExistence(timeout: 10))

        let statusItem = app.descendants(matching: .any).matching(
            NSPredicate(format: "title BEGINSWITH %@", "Granita, ")
        ).firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 30), "Granita's status item is absent")
        statusItem.click()
        let showWorktrees = app.menuItems["Show Worktrees"].firstMatch
        XCTAssertTrue(showWorktrees.waitForExistence(timeout: 10), "the status menu has no Show Worktrees")
        XCTAssertTrue(showWorktrees.isEnabled, "the server's state disabled local reading")

        // when
        showWorktrees.click()

        // then
        let reader = app.windows.containing(.any, identifier: "This Mac").firstMatch
        XCTAssertTrue(reader.waitForExistence(timeout: 30), "Show Worktrees did not open This Mac")
        let openProjects = reader.buttons["Open Projects Settings…"].firstMatch
        XCTAssertTrue(openProjects.waitForExistence(timeout: 30), "the local empty state has no Projects recovery")
        openProjects.click()
        XCTAssertTrue(settings.waitForExistence(timeout: 30), "Projects recovery did not open the Projects pane")
    }

    func testChoosingALocalWorktreeKeepsItsSidebarAndRestoresItsDetailAfterClosing() throws {
        // given
        let repository = try makeRepository(named: "granita-local-reader-test")
        let branch = Process()
        let branchOutput = Pipe()
        branch.executableURL = URL(filePath: try XCTUnwrap(
            Bundle(for: Self.self).object(forInfoDictionaryKey: "GranitaTestGitPath") as? String
        ))
        branch.arguments = ["-C", repository.path, "symbolic-ref", "--short", "HEAD"]
        branch.standardOutput = branchOutput
        try branch.run()
        branch.waitUntilExit()
        XCTAssertEqual(branch.terminationStatus, 0, "the fixture has no initial branch")
        let displayName = String(
            decoding: branchOutput.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertFalse(displayName.isEmpty)

        let app = launch(withProjects: [repository])
        let settings = app.windows["Projects"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 30))
        let toggle = app.descendants(matching: .any)["granita.projects.visible.\(repository.id)"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        toggle.click()
        expectStored(isVisible: true, forProjectAt: repository.path)
        settings.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(settings.waitForNonExistence(timeout: 10))

        let statusItem = app.descendants(matching: .any).matching(
            NSPredicate(format: "title BEGINSWITH %@", "Granita, ")
        ).firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 30))
        statusItem.click()
        let showWorktrees = app.menuItems["Show Worktrees"].firstMatch
        XCTAssertTrue(showWorktrees.waitForExistence(timeout: 10))
        showWorktrees.click()

        let reader = app.windows.containing(.any, identifier: "This Mac").firstMatch
        XCTAssertTrue(reader.waitForExistence(timeout: 30))
        // An empty fixture is normally hidden; the preference can already be on from an earlier run.
        let showQuiet = reader.buttons["Show them anyway"].firstMatch
        if showQuiet.waitForExistence(timeout: 10) {
            showQuiet.click()
        }
        let row = reader.descendants(matching: .outlineRow)
            .containing(.any, identifier: displayName).firstMatch
        XCTAssertTrue(
            row.waitForExistence(timeout: 30),
            "the enabled repository's \(displayName) worktree was not listed. Reader: \(reader.debugDescription)"
        )

        // when
        row.staticTexts[displayName].firstMatch.click()

        // then
        let emptyDiff = reader.staticTexts["This worktree has no uncommitted changes."].firstMatch
        XCTAssertTrue(emptyDiff.waitForExistence(timeout: 30), "choosing the row did not open its detail")
        XCTAssertTrue(row.exists, "opening detail replaced the worktree sidebar")

        reader.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(reader.waitForNonExistence(timeout: 10))
        statusItem.click()
        XCTAssertTrue(showWorktrees.waitForExistence(timeout: 10))
        showWorktrees.click()
        XCTAssertTrue(reader.waitForExistence(timeout: 30))
        XCTAssertTrue(emptyDiff.waitForExistence(timeout: 30), "reopening forgot the selected worktree")
        XCTAssertTrue(row.exists, "reopening lost the persistent worktree sidebar")
    }

    func testClosingTheWorktreeWindowLeavesTheServerServingAndItsStatusItemAvailable() throws {
        // given
        let app = launch(withProjects: [])
        let settings = app.windows["Projects"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 30))
        let general = app.descendants(matching: .any)["General"].firstMatch
        XCTAssertTrue(general.waitForExistence(timeout: 10))
        general.click()
        XCTAssertTrue(app.windows["General"].firstMatch.waitForExistence(timeout: 10))
        let startupValues = app.windows["General"].firstMatch.staticTexts.allElementsBoundByIndex
            .map { String(describing: $0.value) }
        let startupDiagnostic = "Values: \(startupValues). Hierarchy: \(app.debugDescription)"
        app.descendants(matching: .any)["Projects"].firstMatch.click()
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(settings.waitForNonExistence(timeout: 10))

        let statusItem = app.descendants(matching: .any).matching(
            NSPredicate(format: "title == %@", "Granita, serving")
        ).firstMatch
        XCTAssertTrue(
            statusItem.waitForExistence(timeout: 30),
            "the serving status item was not found. Startup: \(startupDiagnostic). Current: \(app.debugDescription)"
        )
        statusItem.click()

        let serving = app.menuItems.matching(
            NSPredicate(format: "title BEGINSWITH %@", "Serving on ")
        ).firstMatch
        XCTAssertTrue(serving.waitForExistence(timeout: 10))
        let servingBeforeOpening = serving.title

        let showWorktrees = app.menuItems["Show Worktrees"].firstMatch
        XCTAssertTrue(
            showWorktrees.waitForExistence(timeout: 10),
            "the status menu has no Show Worktrees control"
        )
        showWorktrees.click()

        // The source is visible to a reader; neither a scene identifier nor its window title is
        // part of this assertion. Closing Settings first also leaves the reader as the only window.
        let reader = app.windows.containing(.any, identifier: "This Mac").firstMatch
        XCTAssertTrue(reader.waitForExistence(timeout: 30), "Show Worktrees did not open the reader")

        // when
        reader.typeKey("w", modifierFlags: .command)

        // then
        XCTAssertTrue(reader.waitForNonExistence(timeout: 10), "the reader window did not close")
        XCTAssertNotEqual(app.state, .notRunning, "closing the reader quit Granita")
        XCTAssertTrue(
            statusItem.waitForExistence(timeout: 10),
            "closing the reader removed the serving status item"
        )
        statusItem.click()
        XCTAssertTrue(serving.waitForExistence(timeout: 10), "the status menu no longer reports serving")
        XCTAssertEqual(serving.title, servingBeforeOpening, "closing the reader interrupted the server")
    }

    func testClickingGranitasDockItemReopensTheClosedReaderWhileTheServerKeepsServing() throws {
        // given
        let app = launch(withProjects: [], defaultsArguments: [
            "-granita.reader.selection.source", "thisMac",
            "-granita.reader.selection.worktreeId", ""
        ])
        let settings = app.windows["Projects"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 30))
        settings.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(settings.waitForNonExistence(timeout: 10))
        let statusItem = app.statusItems.matching(
            NSPredicate(format: "title == %@", "Granita, serving")
        ).firstMatch
        XCTAssertTrue(
            statusItem.waitForExistence(timeout: 30),
            "the fixture never began serving. Granita: \(app.debugDescription)"
        )
        statusItem.click()
        let serving = app.menuItems.matching(
            NSPredicate(format: "title BEGINSWITH %@", "Serving on ")
        ).firstMatch
        XCTAssertTrue(serving.waitForExistence(timeout: 10))
        let servingBeforeClosing = serving.title
        let showWorktrees = app.menuItems["Show Worktrees"].firstMatch
        XCTAssertTrue(showWorktrees.waitForExistence(timeout: 10))
        showWorktrees.click()
        let reader = app.windows.containing(.any, identifier: "This Mac").firstMatch
        XCTAssertTrue(reader.waitForExistence(timeout: 30))
        XCTAssertTrue(reader.buttons["Open Projects Settings…"].firstMatch.waitForExistence(timeout: 10))
        reader.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(reader.waitForNonExistence(timeout: 10), "the reader never closed")
        XCTAssertNotEqual(app.state, .notRunning, "closing the reader quit Granita")

        // when — send the actual Dock reopen event, through the Dock's own application hierarchy.
        let dock = XCUIApplication(bundleIdentifier: "com.apple.dock")
        let granita = dock.dockItems["Granita"].firstMatch
        XCTAssertTrue(granita.waitForExistence(timeout: 10), "Granita has no Dock item")
        granita.click()

        // then
        XCTAssertTrue(
            reader.waitForExistence(timeout: 30),
            "clicking the Dock item did not reopen the reader. Granita: \(app.debugDescription)"
        )
        XCTAssertTrue(reader.buttons["Open Projects Settings…"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(statusItem.waitForExistence(timeout: 10), "Dock reopen lost the serving status item")
        statusItem.click()
        XCTAssertTrue(serving.waitForExistence(timeout: 10), "Dock reopen stopped the server")
        XCTAssertEqual(serving.title, servingBeforeClosing, "Dock reopen replaced the serving endpoint")
    }

    func testViewMenuCodeSizeChangesVisibleCodeAndRestoresItsSystemSize() throws {
        // given
        let repository = try makeRepository(named: "granita-code-size-test")
        let branch = Process()
        branch.executableURL = URL(filePath: try XCTUnwrap(
            Bundle(for: Self.self).object(forInfoDictionaryKey: "GranitaTestGitPath") as? String
        ))
        branch.arguments = [
            "-c", "core.pager=cat", "-c", "color.ui=false", "-c", "core.quotePath=false", "--no-pager",
            "-C", repository.path, "symbolic-ref", "HEAD", "refs/heads/code-size-fixture"
        ]
        try branch.run()
        branch.waitUntilExit()
        XCTAssertEqual(branch.terminationStatus, 0, "the fixture branch could not be named")
        let codeLine = "let granitaCodeSizeFixture = \"Visible code changes size\""
        try Data("\(codeLine)\n".utf8).write(
            to: URL(filePath: repository.path).appending(path: "CodeSizeFixture.swift")
        )

        let app = launch(withProjects: [repository], defaultsArguments: [
            "-granita.reader.selection.source", "thisMac",
            "-granita.reader.selection.worktreeId", "",
            "-granita.appearance.sideBySide", "NO"
        ])
        let settings = app.windows["Projects"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 30))
        let toggle = app.descendants(matching: .any)["granita.projects.visible.\(repository.id)"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        toggle.click()
        expectStored(isVisible: true, forProjectAt: repository.path)
        settings.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(settings.waitForNonExistence(timeout: 10))
        let statusItem = app.descendants(matching: .statusItem).matching(
            NSPredicate(format: "title BEGINSWITH %@", "Granita, ")
        ).firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 30))
        statusItem.click()
        let showWorktrees = app.menuItems["Show Worktrees"].firstMatch
        XCTAssertTrue(showWorktrees.waitForExistence(timeout: 10))
        showWorktrees.click()
        let reader = app.windows.containing(.any, identifier: "This Mac").firstMatch
        XCTAssertTrue(reader.waitForExistence(timeout: 30))
        let row = reader.descendants(matching: .outlineRow)
            .containing(.any, identifier: "code-size-fixture").firstMatch
        XCTAssertTrue(
            row.waitForExistence(timeout: 30),
            "the fixture worktree was not listed. Reader: \(reader.debugDescription)"
        )
        row.staticTexts["code-size-fixture"].firstMatch.click()
        let code = reader.staticTexts[codeLine].firstMatch
        XCTAssertTrue(
            code.waitForExistence(timeout: 30),
            "the fixture's code was not visible. Reader: \(reader.debugDescription)"
        )

        let viewMenu = app.menuBars.menuBarItems["View"].firstMatch
        XCTAssertTrue(viewMenu.waitForExistence(timeout: 10), "the app has no native View menu")
        viewMenu.click()
        let actualSize = app.menuItems["Actual Code Size"].firstMatch
        XCTAssertTrue(actualSize.waitForExistence(timeout: 10))
        if actualSize.isEnabled {
            actualSize.click()
        } else {
            reader.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
        }
        viewMenu.click()
        XCTAssertTrue(actualSize.waitForExistence(timeout: 10))
        XCTAssertFalse(actualSize.isEnabled, "the code did not return to system size before measurement")
        reader.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
        let systemFrame = code.frame
        XCTAssertGreaterThan(systemFrame.width, 0)
        XCTAssertGreaterThan(systemFrame.height, 0)

        // when
        viewMenu.click()
        let increase = app.menuItems["Increase Code Size"].firstMatch
        XCTAssertTrue(increase.waitForExistence(timeout: 10))
        XCTAssertTrue(increase.isEnabled)
        increase.click()

        // then
        let enlarged = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                code.exists && code.frame.width > systemFrame.width && code.frame.height > systemFrame.height
            },
            object: code
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [enlarged], timeout: 10),
            .completed,
            "Increase Code Size did not enlarge the visible code. Before: \(systemFrame), after: \(code.frame)"
        )
        XCTAssertTrue(row.exists, "changing code size removed the sidebar")
        viewMenu.click()
        XCTAssertTrue(actualSize.waitForExistence(timeout: 10))
        XCTAssertTrue(actualSize.isEnabled)
        actualSize.click()
        let restored = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                code.exists && abs(code.frame.width - systemFrame.width) < 1
                    && abs(code.frame.height - systemFrame.height) < 1
            },
            object: code
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [restored], timeout: 10),
            .completed,
            "Actual Code Size did not restore the visible code. Before: \(systemFrame), after: \(code.frame)"
        )
    }

    func testViewCodeColoursOffersAccessibleDirectlyAndRecoloursVisibleCode() throws {
        // given
        let repository = try makeRepository(named: "granita-code-colours-test")
        let branch = Process()
        branch.executableURL = URL(filePath: try XCTUnwrap(
            Bundle(for: Self.self).object(forInfoDictionaryKey: "GranitaTestGitPath") as? String
        ))
        branch.arguments = [
            "-c", "core.pager=cat", "-c", "color.ui=false", "-c", "core.quotePath=false", "--no-pager",
            "-C", repository.path, "symbolic-ref", "HEAD", "refs/heads/code-colours-fixture"
        ]
        try branch.run()
        branch.waitUntilExit()
        XCTAssertEqual(branch.terminationStatus, 0, "the fixture branch could not be named")
        let codeLine = "let granitaCodeSizeFixture = \"Visible code changes size\""
        try Data("\(codeLine)\n".utf8).write(
            to: URL(filePath: repository.path).appending(path: "CodeSizeFixture.swift")
        )
        let app = launch(withProjects: [repository], defaultsArguments: [
            "-granita.reader.selection.source", "thisMac",
            "-granita.reader.selection.worktreeId", "",
            "-granita.appearance.sideBySide", "NO",
            "-granita.appearance.codeTheme", "xcode"
        ])
        let settings = app.windows["Projects"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 30))
        let toggle = app.descendants(matching: .any)["granita.projects.visible.\(repository.id)"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        toggle.click()
        expectStored(isVisible: true, forProjectAt: repository.path)
        settings.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(settings.waitForNonExistence(timeout: 10))
        let statusItem = app.statusItems.matching(
            NSPredicate(format: "title BEGINSWITH %@", "Granita, ")
        ).firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 30))
        statusItem.click()
        let showWorktrees = app.menuItems["Show Worktrees"].firstMatch
        XCTAssertTrue(showWorktrees.waitForExistence(timeout: 10))
        showWorktrees.click()
        let reader = app.windows.containing(.any, identifier: "This Mac").firstMatch
        XCTAssertTrue(reader.waitForExistence(timeout: 30))
        let row = reader.descendants(matching: .outlineRow)
            .containing(.any, identifier: "code-colours-fixture").firstMatch
        XCTAssertTrue(
            row.waitForExistence(timeout: 30),
            "the fixture worktree was not listed. Reader: \(reader.debugDescription)"
        )
        row.staticTexts["code-colours-fixture"].firstMatch.click()
        let code = reader.staticTexts[codeLine].firstMatch
        XCTAssertTrue(
            code.waitForExistence(timeout: 30),
            "the fixture's code was not visible. Reader: \(reader.debugDescription)"
        )
        let xcodeFrame = code.frame
        let xcodeScreenshot = code.screenshot()
        let xcodePixels = xcodeScreenshot.pngRepresentation
        let initialReader = XCTAttachment(screenshot: reader.screenshot())
        initialReader.name = "Reader with Xcode colours and selected worktree"
        initialReader.lifetime = .keepAlways
        add(initialReader)

        // when — open only the one Code Colours submenu immediately under View.
        let viewMenu = app.menuBars.menuBarItems["View"].firstMatch
        XCTAssertTrue(viewMenu.waitForExistence(timeout: 10))
        viewMenu.click()
        let colours = app.menuItems["Code Colours"].firstMatch
        XCTAssertTrue(colours.waitForExistence(timeout: 10))
        colours.hover()
        let submenu = colours.children(matching: .menu).firstMatch
        XCTAssertTrue(submenu.waitForExistence(timeout: 10))

        // then
        XCTAssertEqual(
            submenu.children(matching: .menuItem).matching(
                NSPredicate(format: "title == %@", "Code Colours")
            ).count,
            0,
            "Code Colours contains a second Code Colours submenu. Menu: \(submenu.debugDescription)"
        )
        let accessible = submenu.children(matching: .menuItem).matching(
            NSPredicate(format: "title == %@", "Accessible")
        ).firstMatch
        XCTAssertTrue(
            accessible.waitForExistence(timeout: 10),
            "Accessible is not a direct theme choice. Menu: \(submenu.debugDescription)"
        )
        XCTAssertTrue(accessible.isHittable, "Accessible requires opening another submenu")
        accessible.click()

        let recoloured = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                code.exists && code.screenshot().pngRepresentation != xcodePixels
            },
            object: code
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [recoloured], timeout: 10),
            .completed,
            "choosing Accessible did not change the visible code's colours"
        )
        XCTAssertEqual(code.frame.size, xcodeFrame.size, "choosing colours changed the code's geometry")
        let before = XCTAttachment(screenshot: xcodeScreenshot)
        before.name = "Xcode code colours"
        before.lifetime = .keepAlways
        add(before)
        let after = XCTAttachment(screenshot: code.screenshot())
        after.name = "Accessible code colours"
        after.lifetime = .keepAlways
        add(after)
        let recolouredReader = XCTAttachment(screenshot: reader.screenshot())
        recolouredReader.name = "Reader with Accessible colours and selected worktree"
        recolouredReader.lifetime = .keepAlways
        add(recolouredReader)

        // Restore the fixture's initial theme and prove the colour change reverses on the same code.
        viewMenu.click()
        XCTAssertTrue(colours.waitForExistence(timeout: 10))
        colours.hover()
        let xcode = submenu.children(matching: .menuItem).matching(
            NSPredicate(format: "title == %@", "Xcode")
        ).firstMatch
        XCTAssertTrue(xcode.waitForExistence(timeout: 10))
        XCTAssertTrue(xcode.isHittable)
        xcode.click()
        let restored = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                code.exists && code.screenshot().pngRepresentation == xcodePixels
            },
            object: code
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [restored], timeout: 10),
            .completed,
            "choosing Xcode did not restore the visible code's original colours"
        )
    }

    func testViewSideBySidePlacesTheOldAndNewCodeInTwoColumns() throws {
        // given
        let fixture = try makeChangedCodeFixture(named: "granita-side-by-side-test")
        let (app, reader) = openChangedCodeFixture(fixture)
        let oldCode = reader.staticTexts[fixture.before].firstMatch
        let newCode = reader.staticTexts[fixture.after].firstMatch
        XCTAssertGreaterThan(abs(oldCode.frame.midY - newCode.frame.midY), 1)
        let viewMenu = app.menuBars.menuBarItems["View"].firstMatch
        XCTAssertTrue(viewMenu.waitForExistence(timeout: 10))

        // when
        viewMenu.click()
        let sideBySide = app.menuItems["Side by Side"].firstMatch
        XCTAssertTrue(sideBySide.waitForExistence(timeout: 10))
        XCTAssertTrue(sideBySide.isEnabled)
        sideBySide.click()

        // then
        let columns = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                oldCode.exists && newCode.exists
                    && abs(oldCode.frame.midY - newCode.frame.midY) < 1
                    && oldCode.frame.maxX < newCode.frame.minX
            },
            object: reader
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [columns], timeout: 10),
            .completed,
            "Side by Side did not put old and new code in distinct columns. Old: \(oldCode.frame), new: \(newCode.frame)"
        )
        let screenshot = XCTAttachment(screenshot: reader.screenshot())
        screenshot.name = "Native side-by-side code columns"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        viewMenu.click()
        XCTAssertTrue(sideBySide.waitForExistence(timeout: 10))
        sideBySide.click()
        let unified = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                oldCode.exists && newCode.exists && abs(oldCode.frame.midY - newCode.frame.midY) > 1
            },
            object: reader
        )
        XCTAssertEqual(XCTWaiter.wait(for: [unified], timeout: 10), .completed)
    }

    func testViewInspectorControlsHideAndRestoreTheVisibleFilesInspector() throws {
        // given
        let fixture = try makeChangedCodeFixture(named: "granita-inspector-test")
        let (app, reader) = openChangedCodeFixture(fixture)
        let files = reader.staticTexts["Files"].firstMatch
        XCTAssertTrue(files.waitForExistence(timeout: 10), "the chosen worktree has no Files inspector")
        let code = reader.staticTexts[fixture.after].firstMatch
        let viewMenu = app.menuBars.menuBarItems["View"].firstMatch
        XCTAssertTrue(viewMenu.waitForExistence(timeout: 10))

        // when
        viewMenu.click()
        let hideInspector = app.menuItems["Hide Inspector"].firstMatch
        XCTAssertTrue(hideInspector.waitForExistence(timeout: 10))
        XCTAssertTrue(hideInspector.isEnabled)
        hideInspector.click()

        // then
        XCTAssertTrue(files.waitForNonExistence(timeout: 10), "Hide Inspector left Files on screen")
        XCTAssertTrue(code.exists, "hiding the inspector removed the diff")
        viewMenu.click()
        let showInspector = app.menuItems["Show Inspector"].firstMatch
        XCTAssertTrue(showInspector.waitForExistence(timeout: 10))
        XCTAssertTrue(showInspector.isEnabled)
        showInspector.click()
        XCTAssertTrue(files.waitForExistence(timeout: 10), "Show Inspector did not restore Files")
        XCTAssertTrue(code.exists, "restoring the inspector removed the diff")
    }

    func testViewRefreshReadsTheChangedRepositoryIntoTheVisibleDiff() throws {
        // given
        let fixture = try makeChangedCodeFixture(named: "granita-refresh-test", includingSecondFile: true)
        let (app, reader) = openChangedCodeFixture(fixture)
        let secondBefore = "let granitaSecondControlFixture = \"before\""
        let secondAfter = "let granitaSecondControlFixture = \"after\""
        XCTAssertTrue(reader.staticTexts[secondBefore].firstMatch.waitForExistence(timeout: 30), "the second visible file did not load. Reader: \(reader.debugDescription)")
        XCTAssertTrue(reader.staticTexts[secondAfter].firstMatch.waitForExistence(timeout: 30))
        let refreshedLine = "let granitaControlFixture = \"refreshed from disk\""
        try Data("\(refreshedLine)\n".utf8).write(to: fixture.file)
        let secondRefreshedLine = "let granitaSecondControlFixture = \"also refreshed from disk\""
        let secondFile = fixture.file.deletingLastPathComponent().appending(path: "SecondCodeControlsFixture.swift")
        try Data("\(secondRefreshedLine)\n".utf8).write(to: secondFile)
        let refreshedCode = reader.staticTexts[refreshedLine].firstMatch
        XCTAssertFalse(refreshedCode.exists, "the fixture changed before Refresh was pressed")
        XCTAssertFalse(reader.staticTexts[secondRefreshedLine].firstMatch.exists)
        let viewMenu = app.menuBars.menuBarItems["View"].firstMatch
        XCTAssertTrue(viewMenu.waitForExistence(timeout: 10))

        // when
        viewMenu.click()
        let refresh = app.menuItems["Refresh"].firstMatch
        XCTAssertTrue(refresh.waitForExistence(timeout: 10))
        XCTAssertTrue(refresh.isEnabled)
        refresh.click()

        // then
        XCTAssertTrue(
            refreshedCode.waitForExistence(timeout: 30),
            "Refresh did not read the new code from disk. Reader: \(reader.debugDescription)"
        )
        XCTAssertFalse(reader.staticTexts[fixture.after].firstMatch.exists, "Refresh retained the old added line")
        XCTAssertTrue(reader.staticTexts[fixture.before].firstMatch.exists, "Refresh lost the diff's old side")
        XCTAssertTrue(reader.staticTexts[secondRefreshedLine].firstMatch.waitForExistence(timeout: 30), "Refresh left the second visible file unread. Reader: \(reader.debugDescription)")
        XCTAssertFalse(reader.staticTexts[secondAfter].firstMatch.exists, "Refresh retained the second file's old added line")
        XCTAssertTrue(reader.staticTexts[secondBefore].firstMatch.exists, "Refresh lost the second diff's old side")
    }

    func testTheChosenWorktreeHasOneNativeHeaderTitleAndAProjectAndSourceSubtitle() throws {
        // given
        let fixture = try makeChangedCodeFixture(named: "granita-header-test")

        // when
        let (_, reader) = openChangedCodeFixture(fixture)

        // then — AppKit exposes the native title and subtitle together on the window.
        let screenshot = XCTAttachment(screenshot: reader.screenshot())
        screenshot.name = "Native reader worktree title and project source subtitle"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        XCTAssertEqual(reader.title, "code-control-fixture – granita-header-test · This Mac")
        let nativeTitle = reader.children(matching: .staticText).matching(NSPredicate(format: "value == %@", "code-control-fixture"))
        XCTAssertEqual(nativeTitle.count, 1, "the native title must appear once. Reader: \(reader.debugDescription)")
        XCTAssertTrue(nativeTitle.firstMatch.isHittable)
        let nativeSubtitle = reader.children(matching: .staticText).matching(NSPredicate(format: "value == %@", "granita-header-test · This Mac"))
        XCTAssertEqual(nativeSubtitle.count, 1, "the native subtitle must appear once. Reader: \(reader.debugDescription)")
        XCTAssertTrue(nativeSubtitle.firstMatch.isHittable)
        let toolbar = reader.toolbars.firstMatch
        XCTAssertTrue(toolbar.waitForExistence(timeout: 10))
        let hierarchy = XCTAttachment(string: toolbar.debugDescription)
        hierarchy.name = "Native reader header accessibility hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        let titles = toolbar.staticTexts.matching(identifier: "code-control-fixture")
        XCTAssertEqual(titles.count, 0, "the toolbar must not repeat the native worktree title. Toolbar: \(toolbar.debugDescription)")
        let subtitles = toolbar.staticTexts.matching(identifier: "granita-header-test · This Mac")
        XCTAssertEqual(subtitles.count, 0, "the toolbar must not repeat the native project and source subtitle. Toolbar: \(toolbar.debugDescription)")
    }

    func testCopyReviewPlacesTheVisibleSavedCommentOnTheClipboard() throws {
        // given
        let clipboard = try ClipboardSnapshot()
        defer { clipboard.restore() }
        let fixture = try makeChangedCodeFixture(named: "granita-copy-review-test")
        let (_, reader) = openChangedCodeFixture(fixture)
        let addedCode = reader.staticTexts[fixture.after].firstMatch
        // The gutter is immediately before the visible code, on the same diff line.
        addedCode.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
            .withOffset(CGVector(dx: -12, dy: 0)).click()
        let composer = reader.sheets.firstMatch
        XCTAssertTrue(composer.waitForExistence(timeout: 10), "the gutter did not open its comment composer. Reader: \(reader.debugDescription)")
        let commentField = composer.descendants(matching: .any)["What is wrong with these lines?"].firstMatch
        XCTAssertTrue(commentField.waitForExistence(timeout: 10))
        let comment = "Please explain this changed value."
        commentField.click()
        commentField.typeText(comment)
        XCTAssertEqual(commentField.value as? String, comment, "the composer did not receive the entire test comment")
        composer.buttons["Save"].firstMatch.click()
        XCTAssertTrue(composer.waitForNonExistence(timeout: 10))
        let showReview = reader.buttons["Show the review"].firstMatch
        XCTAssertTrue(showReview.waitForExistence(timeout: 10))
        showReview.click()
        let visibleComment = reader.staticTexts.matching(NSPredicate(format: "value BEGINSWITH %@", "Please explain")).firstMatch
        XCTAssertTrue(visibleComment.waitForExistence(timeout: 10), "the saved comment is missing from the visible review. Reader: \(reader.debugDescription)")
        XCTAssertTrue(visibleComment.isHittable)
        let copyReview = reader.buttons["Copy review"].firstMatch
        XCTAssertTrue(copyReview.waitForExistence(timeout: 10))

        // when
        NSPasteboard.general.clearContents()
        XCTAssertTrue(NSPasteboard.general.setString("Granita native Copy Review sentinel", forType: .string))
        copyReview.click()

        // then
        let expected = """
            Review of uncommitted changes

            ---

            A. CodeControlsFixture.swift:1
            ```swift
            \(fixture.after)
            ```
            \(comment)
            """
        let copied = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            NSPasteboard.general.string(forType: .string) == expected
        }, object: nil)
        let result = XCTWaiter.wait(for: [copied], timeout: 10)
        let actual = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(result, .completed, "Copy review did not place the visible review document on the clipboard. Actual: \(actual ?? "<no text>")")
    }

    func testCopyLogsPlacesTheFailedPairingDiagnosticReportOnTheClipboard() throws {
        // given
        let clipboard = try ClipboardSnapshot()
        defer { clipboard.restore() }
        let app = launch(withProjects: [], defaultsArguments: [
            "-granita.reader.selection.source", "remote",
            "-granita.reader.selection.instance", "granita-absent-\(UUID().uuidString)",
            "-granita.reader.selection.name", "Absent Mac"
        ])
        let settings = app.windows["Projects"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 30))
        settings.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(settings.waitForNonExistence(timeout: 10))
        let statusItem = app.statusItems.matching(NSPredicate(format: "title BEGINSWITH %@", "Granita, ")).firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 30))
        statusItem.click()
        let showWorktrees = app.menuItems["Show Worktrees"].firstMatch
        XCTAssertTrue(showWorktrees.waitForExistence(timeout: 10))
        showWorktrees.click()
        let reader = app.windows.containing(.any, identifier: "Absent Mac").firstMatch
        XCTAssertTrue(reader.waitForExistence(timeout: 30))
        let pairAgain = reader.buttons["Pair Again"].firstMatch
        XCTAssertTrue(pairAgain.waitForExistence(timeout: 30))
        pairAgain.click()
        let pairing = reader.sheets.firstMatch
        XCTAssertTrue(pairing.waitForExistence(timeout: 10))
        let words = pairing.textFields["six words"].firstMatch
        XCTAssertTrue(words.waitForExistence(timeout: 10))
        words.click()
        let phrase = "amber amber amber amber amber amber"
        words.typeText(phrase)
        let pair = pairing.buttons["Pair"].firstMatch
        XCTAssertTrue(pair.isEnabled)
        pair.click()
        // Four bounded resolver attempts plus the wake delays can take 35 seconds.
        XCTAssertTrue(pairing.staticTexts["Could not reach Absent Mac"].firstMatch.waitForExistence(timeout: 45), "the absent Mac did not show recovery. Reader: \(reader.debugDescription)")
        let copyLogs = pairing.buttons["Copy Logs"].firstMatch
        XCTAssertTrue(copyLogs.waitForExistence(timeout: 10), "the refused pairing has no Copy Logs control. Reader: \(reader.debugDescription)")

        // when
        copyLogs.click()

        // then
        let copied = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let text = NSPasteboard.general.string(forType: .string) else { return false }
            return text.hasPrefix("Granita ") && text.contains("Collected: ")
                && text.hasSuffix("Current screen: pairing\nFailure: unreachable")
                && !text.contains(phrase)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [copied], timeout: 10), .completed, "Copy Logs did not place the failed pairing report on the clipboard")
        XCTAssertTrue(pairing.staticTexts["Logs copied. Paste them into your message."].firstMatch.waitForExistence(timeout: 10))
    }

    func testAnUnpairedRememberedSourceOffersNativeWordsPairingAndCanReturnToThisMac() throws {
        // given
        let app = launch(withProjects: [], defaultsArguments: [
            "-granita.reader.selection.source", "remote",
            "-granita.reader.selection.instance", "granita-unpaired-test",
            "-granita.reader.selection.name", "Remote Mac"
        ])
        let settings = app.windows["Projects"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 30))
        settings.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(settings.waitForNonExistence(timeout: 10))
        let statusItem = app.descendants(matching: .any).matching(
            NSPredicate(format: "title BEGINSWITH %@", "Granita, ")
        ).firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 30))
        statusItem.click()
        let showWorktrees = app.menuItems["Show Worktrees"].firstMatch
        XCTAssertTrue(showWorktrees.waitForExistence(timeout: 10))
        showWorktrees.click()
        let reader = app.windows.containing(.any, identifier: "Remote Mac").firstMatch
        XCTAssertTrue(reader.waitForExistence(timeout: 30), "the remembered remote source did not restore")
        let pairAgain = reader.buttons["Pair Again"].firstMatch
        XCTAssertTrue(
            pairAgain.waitForExistence(timeout: 30),
            "the unpaired remote source has no pairing recovery. Reader: \(reader.debugDescription)"
        )

        // when
        pairAgain.click()

        // then
        let pairing = reader.sheets.firstMatch
        XCTAssertTrue(pairing.waitForExistence(timeout: 10), "Pair Again did not open a native sheet")
        XCTAssertTrue(pairing.staticTexts["Pair with Remote Mac"].firstMatch.exists)
        XCTAssertTrue(pairing.textFields["six words"].firstMatch.exists, "the pairing sheet has no words field")
        XCTAssertTrue(pairing.buttons["Pair"].firstMatch.exists)
        XCTAssertFalse(pairing.buttons["Scan the QR Code"].firstMatch.exists, "Mac pairing offered a camera")
        pairing.buttons["Cancel"].firstMatch.click()
        XCTAssertTrue(pairing.waitForNonExistence(timeout: 10))

        let source = reader.descendants(matching: .any)["granita.reader.source"].firstMatch
        XCTAssertTrue(source.exists)
        source.click()
        let thisMac = app.menuItems.matching(NSPredicate(format: "title BEGINSWITH %@", "This Mac")).firstMatch
        XCTAssertTrue(thisMac.waitForExistence(timeout: 10))
        thisMac.click()
        let localReader = app.windows.containing(.any, identifier: "This Mac").firstMatch
        XCTAssertTrue(localReader.waitForExistence(timeout: 30))
        let openProjects = localReader.buttons["Open Projects Settings…"].firstMatch
        XCTAssertTrue(openProjects.waitForExistence(timeout: 30), "This Mac did not offer local Projects recovery")
        openProjects.click()
        XCTAssertTrue(settings.waitForExistence(timeout: 30), "local Projects recovery did not open Settings")
    }

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

    private struct ChangedCodeFixture {
        let project: SeededProject
        let file: URL
        let before: String
        let after: String
    }

    private func makeChangedCodeFixture(named name: String, includingSecondFile: Bool = false) throws -> ChangedCodeFixture {
        let project = try makeRepository(named: name)
        let file = URL(filePath: project.path).appending(path: "CodeControlsFixture.swift")
        let before = "let granitaControlFixture = \"before\""
        let after = "let granitaControlFixture = \"after\""
        try Data("\(before)\n".utf8).write(to: file)
        let secondFile = file.deletingLastPathComponent().appending(path: "SecondCodeControlsFixture.swift")
        if includingSecondFile {
            try Data("let granitaSecondControlFixture = \"before\"\n".utf8).write(to: secondFile)
        }
        let gitUrl = URL(filePath: try XCTUnwrap(
            Bundle(for: Self.self).object(forInfoDictionaryKey: "GranitaTestGitPath") as? String
        ))
        let commands = [
            ["symbolic-ref", "HEAD", "refs/heads/code-control-fixture"],
            ["add", "--", "CodeControlsFixture.swift"] + (includingSecondFile ? ["SecondCodeControlsFixture.swift"] : []),
            ["commit", "--quiet", "--no-verify", "--no-gpg-sign", "-m", "Seed native reader fixture"]
        ]
        for command in commands {
            let git = Process()
            git.executableURL = gitUrl
            git.arguments = [
                "-c", "core.pager=cat", "-c", "color.ui=false", "-c", "core.quotePath=false", "--no-pager",
                "-c", "core.hooksPath=/dev/null", "-c", "user.name=Granita UI Fixture",
                "-c", "user.email=granita-fixture@example.invalid", "-C", project.path
            ] + command
            try git.run()
            git.waitUntilExit()
            XCTAssertEqual(git.terminationStatus, 0, "the fixture command failed: \(command)")
        }
        try Data("\(after)\n".utf8).write(to: file)
        if includingSecondFile {
            try Data("let granitaSecondControlFixture = \"after\"\n".utf8).write(to: secondFile)
        }
        return ChangedCodeFixture(project: project, file: file, before: before, after: after)
    }

    private func openChangedCodeFixture(_ fixture: ChangedCodeFixture) -> (XCUIApplication, XCUIElement) {
        let app = launch(withProjects: [fixture.project], defaultsArguments: [
            "-granita.reader.selection.source", "thisMac",
            "-granita.reader.selection.worktreeId", "",
            "-granita.appearance.sideBySide", "NO"
        ])
        let settings = app.windows["Projects"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 30))
        let toggle = app.descendants(matching: .any)["granita.projects.visible.\(fixture.project.id)"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        toggle.click()
        expectStored(isVisible: true, forProjectAt: fixture.project.path)
        settings.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(settings.waitForNonExistence(timeout: 10))
        let statusItem = app.statusItems.matching(
            NSPredicate(format: "title BEGINSWITH %@", "Granita, ")
        ).firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 30))
        statusItem.click()
        let showWorktrees = app.menuItems["Show Worktrees"].firstMatch
        XCTAssertTrue(showWorktrees.waitForExistence(timeout: 10))
        showWorktrees.click()
        let reader = app.windows.containing(.any, identifier: "This Mac").firstMatch
        XCTAssertTrue(reader.waitForExistence(timeout: 30))
        let row = reader.descendants(matching: .outlineRow)
            .containing(.any, identifier: "code-control-fixture").firstMatch
        XCTAssertTrue(
            row.waitForExistence(timeout: 30),
            "the fixture worktree was not listed. Reader: \(reader.debugDescription)"
        )
        row.staticTexts["code-control-fixture"].firstMatch.click()
        XCTAssertTrue(reader.staticTexts[fixture.before].firstMatch.waitForExistence(timeout: 30))
        XCTAssertTrue(reader.staticTexts[fixture.after].firstMatch.waitForExistence(timeout: 30))
        return (app, reader)
    }

    private struct ClipboardSnapshot {
        private struct Representation {
            let type: NSPasteboard.PasteboardType
            let data: Data
        }

        private let items: [[Representation]]

        init() throws {
            items = try (NSPasteboard.general.pasteboardItems ?? []).map { item in
                try item.types.map { type in
                    Representation(type: type, data: try XCTUnwrap(item.data(forType: type), "the existing clipboard representation could not be preserved"))
                }
            }
        }

        func restore() {
            let restored = items.map { representations in
                let item = NSPasteboardItem()
                for representation in representations {
                    item.setData(representation.data, forType: representation.type)
                }
                return item
            }
            NSPasteboard.general.clearContents()
            if !restored.isEmpty {
                XCTAssertTrue(NSPasteboard.general.writeObjects(restored), "the prior clipboard contents could not be restored")
            }
        }
    }

    private func launch(withProjects projects: [SeededProject], defaultsArguments: [String] = []) -> XCUIApplication {
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
        app.launchArguments = ["--store", storeUrl.path(percentEncoded: false), "--port", "0", "--preferences-suite", preferencesSuite, "--open-settings"]
            + defaultsArguments
        app.launch()
        // Select the pane through its real control; the window can open on a remembered pane.
        let projects = app.descendants(matching: .any)["Projects"].firstMatch
        let projectsOpened = projects.waitForExistence(timeout: 30)
        if !projectsOpened {
            XCTFail("Settings did not expose its Projects tab at launch. Granita: \(app.debugDescription)")
            return app
        }
        projects.click()
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
        git.executableURL = URL(filePath: try XCTUnwrap(
            Bundle(for: Self.self).object(forInfoDictionaryKey: "GranitaTestGitPath") as? String
        ))
        git.arguments = ["init", "--quiet", url.path(percentEncoded: false)]
        try git.run()
        git.waitUntilExit()
        XCTAssertEqual(git.terminationStatus, 0, "the fixture repository could not be created")
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
