import Foundation
import SwiftUI
import Testing
import UIKit

import SnapshotTesting

import ClientViewerDomain
import ClientViewerPresentation
import ClientViewerUi
import ClientWorktreesPresentation
import CoreDiffDomain
import CoreReviewDomain

@Suite("App Store screenshots", .serialized)
@MainActor
struct AppStoreScreenshotTests {
    @Test func `given the store demo when exported then each device gets a complete gallery`() async throws {
        // Ordinary snapshot runs never write release artwork.
        guard let path = ProcessInfo.processInfo.environment["GRANITA_STORE_SCREENSHOTS_DIRECTORY"] else {
            return
        }
        let output = URL(filePath: path, directoryHint: .isDirectory)
        try await exportGallery(for: .iPhone, to: output)
        try await exportGallery(for: .iPad, to: output)
        let phoneDiffs = StoreDemo.presentationDiffs
        let phoneLight = try await capture(.diff, for: .iPhone, style: .light, entries: phoneDiffs)
        let phoneDark = try await capture(.diff, for: .iPhone, style: .dark, entries: phoneDiffs)
        let macSnapshots = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "GranitaMacSnapshotTests/__Snapshots__", directoryHint: .isDirectory)
        try exportMacGallery(from: macSnapshots, to: output)
        let macLightFile = macSnapshots.appending(path: MacReleaseScreenshot.review.baseline.path)
        let macDarkFile = macSnapshots.appending(
            path: "MacReaderScreenSnapshotTests/reader-subject-appearance.inspector-review-two-comments-dark.png"
        )
        let macLight = try #require(UIImage(contentsOfFile: macLightFile.path))
        let macDark = try #require(UIImage(contentsOfFile: macDarkFile.path))
        let phoneLightRaster = try #require(phoneLight.cgImage)
        try #require(CGSize(width: phoneLightRaster.width, height: phoneLightRaster.height) == StoreDevice.iPhone.pixels)
        try #require(phoneLight.size == phoneDark.size)
        try #require(macLight.size == macDark.size)
        let icon = try #require(UIImage(named: "AppIconPreview-Granita"))
        let light = PresentationScreens(phone: phoneLight, mac: macLight, appearance: .light)
        let dark = PresentationScreens(phone: phoneDark, mac: macDark, appearance: .dark)

        for split in PresentationSplit.allCases {
            let renderer = ImageRenderer(content: StorePresentation(icon: icon, light: light, dark: dark, split: split))
            renderer.isOpaque = true
            let image = try #require(renderer.uiImage)
            try verifySplit(in: image, split: split)
            try save(image, pixels: CGSize(width: 1600, height: 900), to: output.appending(path: split.rawValue + ".png"))
        }
    }

    private func verifySplit(in image: UIImage, split: PresentationSplit) throws {
        let raster = try #require(image.cgImage)
        let phoneLightBrightness = try brightness(in: raster, at: CGPoint(x: 735, y: 552))
        let phoneDarkBrightness = try brightness(in: raster, at: CGPoint(x: 905, y: 552))
        let macLightBrightness = try brightness(in: raster, at: CGPoint(x: 1000, y: 422))
        let macDarkBrightness = try brightness(in: raster, at: CGPoint(x: 1440, y: 422))
        #expect(phoneLightBrightness > 180 && phoneDarkBrightness < 90, "The theme split should cross the phone display.")
        #expect(macLightBrightness > 180 && macDarkBrightness < 90, "The theme split should cross the Mac display.")
        let lowerDiffRows = try [710, 735, 760, 785].filter { y in
            try brightness(in: raster, at: CGPoint(x: 835, y: y)) > 16
        }
        #expect(lowerDiffRows.count >= 3, "Diff cards should fill the lower part of the phone display.")
        if split == .zigzag {
            let belowPhoneDiagonal = try brightness(in: raster, at: CGPoint(x: 735, y: 570))
            #expect(belowPhoneDiagonal < 90, "The iPhone cut should follow the Mac's shallower angle.")

            let nearPhoneAboveMacLine = try brightness(in: raster, at: CGPoint(x: 985, y: 466))
            let nearPhoneBelowMacLine = try brightness(in: raster, at: CGPoint(x: 985, y: 560))
            #expect(
                nearPhoneAboveMacLine > 180 && nearPhoneBelowMacLine < 90,
                "The Mac's right-hand diagonal should reach the phone without a bend."
            )
        }
    }

    private func brightness(in raster: CGImage, at point: CGPoint) throws -> Int {
        let bounds = CGRect(origin: .zero, size: CGSize(width: 1, height: 1))
        let pixel = try #require(raster.cropping(to: bounds.offsetBy(dx: point.x, dy: point.y)))
        var bytes = [UInt8](repeating: 0, count: 4)
        try bytes.withUnsafeMutableBytes { storage in
            let context = try #require(CGContext(
                data: storage.baseAddress,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ))
            context.draw(pixel, in: bounds)
        }
        return bytes.prefix(3).map(Int.init).reduce(0, +) / 3
    }

    private func exportGallery(for device: StoreDevice, to output: URL) async throws {
        let directory = output.appending(path: device.rawValue, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for scene in StoreScene.allCases {
            let style: UIUserInterfaceStyle = scene == .diff || (device == .iPad && scene == .comments) ? .dark : .light
            let image = try await capture(scene, for: device, style: style, entries: StoreDemo.diffs)
            try save(image, pixels: device.pixels, to: directory.appending(path: scene.rawValue + ".png"))
        }
    }

    private func exportMacGallery(from snapshots: URL, to output: URL) throws {
        let directory = output.appending(path: "Mac", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for screenshot in MacReleaseScreenshot.allCases {
            let baseline = screenshot.baseline
            let source = snapshots.appending(path: baseline.path)
            let data = try Data(contentsOf: source)
            let raster = try #require(UIImage(data: data)?.cgImage, "Could not decode \(baseline.path)")
            let pixels = CGSize(width: raster.width, height: raster.height)
            try #require(pixels == baseline.pixels, "\(baseline.path) has the wrong dimensions")
            // Keep the original Mac window mask and pixel data.
            try data.write(to: directory.appending(path: screenshot.rawValue + ".png"), options: .atomic)
        }
    }

    private func capture(
        _ scene: StoreScene,
        for device: StoreDevice,
        style: UIUserInterfaceStyle,
        entries: [ContinuousDiffEntry]
    ) async throws -> UIImage {
        let layout = device.layout(style: style)
        let diff = await aLoadedViewerModel(
            of: entries,
            holding: scene == .worktrees || scene == .diff ? [] : StoreDemo.comments,
            in: layout
        )
        let root: AnyView
        if scene == .worktrees {
            let list = ClientWorktreesModel(
                macName: aMacName,
                repository: FakeGranitaRepository(worktrees: StoreDemo.worktrees, writeFailure: nil),
                preferences: FakeWorktreeListPreferences(mode: .groupedByProject, showsQuiet: false),
                copyingLogs: FakeDiagnosticLogsCopying(),
                announcing: FakeWorktreeReadAnnouncing(),
                now: { aFixedMoment }
            )
            await list.load()
            root = AnyView(NavigationStack {
                WorktreeSplitScreen(model: list, onPairAgain: {}, settings: { EmptyView() }) {
                    _, name, _, _ in
                    WorktreeDiffScreen(worktreeName: name, model: diff, onPairAgain: {})
                }
            })
        } else {
            root = AnyView(NavigationStack {
                WorktreeDiffScreen(worktreeName: "TLS pinning", model: diff, onPairAgain: {})
            })
        }

        let screen = root.environment(
            \.sideBySide,
            SideBySideSetting(isOn: device == .iPad && scene == .diff, choose: { _ in })
        )
        return try captureStoreScreen(screen, layout: layout) {
            switch scene {
            case .diff, .worktrees:
                break
            case .comments:
                let comment = try #require(StoreDemo.comments.first)
                diff.tappedGutter(comment.anchor.first, in: comment.anchor.file)
                try #require(diff.editingComment == comment)
            case .export:
                diff.noteDraft = "Keep pin validation in the pairing flow."
                diff.showReview()
                diff.showDocument(true)
            }
        }
    }

    private func save(_ image: UIImage, pixels: CGSize, to url: URL) throws {
        let raster = try #require(image.cgImage)
        try #require(CGSize(width: raster.width, height: raster.height) == pixels, "\(url.lastPathComponent) has the wrong dimensions")
        try #require(raster.alphaInfo == .noneSkipLast || raster.alphaInfo == .noneSkipFirst || raster.alphaInfo == .none)
        let data = try #require(image.pngData())
        try data.write(to: url, options: .atomic)
    }
}

private enum StoreScene: String, CaseIterable {
    case diff = "01-read-diffs"
    case worktrees = "02-browse-worktrees"
    case comments = "03-comment-on-code"
    case export = "04-export-review"
}

private enum MacReleaseScreenshot: String, CaseIterable {
    case diff = "01-read-diffs"
    case comment = "02-comment-on-code"
    case review = "03-export-review"
    case pair = "04-pair-a-device"

    var baseline: (path: String, pixels: CGSize) {
        let reader = "MacReaderScreenSnapshotTests/reader-subject-appearance."
        switch self {
        case .diff:
            return (reader + "inspector-tree-with-a-closed-folder-light.png", CGSize(width: 2520, height: 1600))
        case .comment:
            return (reader + "comment-composer-for-an-existing-comment-dark.png", CGSize(width: 940, height: 720))
        case .review:
            return (reader + "inspector-review-two-comments-light.png", CGSize(width: 2520, height: 1600))
        case .pair:
            return (
                "DevicesSettingsViewSnapshotTests/"
                    + "given-nothing-has-paired-when-Devices-renders-then-it-matches-its-baseline-appearance.nothing-paired-dark.png",
                CGSize(width: 1240, height: 1120)
            )
        }
    }
}

private enum StoreDevice: String {
    case iPhone
    case iPad

    var pixels: CGSize {
        switch self {
        case .iPhone: CGSize(width: 1320, height: 2868)
        case .iPad: CGSize(width: 2752, height: 2064)
        }
    }

    func layout(style: UIUserInterfaceStyle) -> SnapshotLayout {
        let scale: CGFloat = self == .iPhone ? 3 : 2
        let traits = UITraitCollection {
            $0.userInterfaceIdiom = self == .iPhone ? .phone : .pad
            $0.horizontalSizeClass = self == .iPhone ? .compact : .regular
            $0.verticalSizeClass = .regular
            $0.displayScale = scale
            $0.preferredContentSizeCategory = .large
            $0.userInterfaceStyle = style
        }
        return SnapshotLayout(
            name: rawValue,
            configuration: ViewImageConfig(
                size: CGSize(width: pixels.width / scale, height: pixels.height / scale),
                traits: traits
            ),
            style: style
        )
    }
}

/// Fictional code with short lines that fit the phone's default code size.
private enum StoreDemo {
    static let diffs = entries(from: patch)
    static let presentationDiffs = diffs + entries(from: presentationPatch)

    static let comments: [ReviewComment] = [
        comment(
            path: "Sources/Connection/PairingClient.swift",
            line: 8,
            quote: "        try pins.check(pin, for: mac)",
            text: "What happens if the Mac rotates its certificate?"
        ),
        comment(
            path: "Tests/Connection/PairingTests.swift",
            line: 7,
            quote: "        try await client.pair(mac)",
            text: "Add a test for a Mac with an unknown pin."
        )
    ]

    static let worktrees: [Worktree] = [
        Worktree(
            id: WorktreeID(rawValue: "store-demo-pairing"),
            projectId: ProjectID(rawValue: "granita"),
            projectName: "granita",
            branch: "feat/tls-pinning",
            isPrimary: false,
            isDetached: false,
            isLocked: false,
            hasUnbornHead: false,
            alias: "TLS pinning",
            suggestedAlias: nil,
            displayName: "TLS pinning",
            directoryName: "granita-pairing",
            isPinned: true,
            stats: ChangeStats(
                filesChanged: diffs.count,
                insertions: diffs.reduce(0) { $0 + $1.file.stats.insertions },
                deletions: diffs.reduce(0) { $0 + $1.file.stats.deletions }
            ),
            lastModified: aFixedMoment.addingTimeInterval(-4 * 60),
            revision: "demo"
        ).withViewedFileCount(1)
    ] + aBusyMac.dropFirst().filter { $0.branch != nil }

    private static func entries(from patch: String) -> [ContinuousDiffEntry] {
        UnifiedDiffParser.parse(patch).compactMap { parsed in
            guard let hunk = parsed.hunks.last else { return nil }
            let lines = parsed.hunks.flatMap(\.lines)
            let additions = lines.filter { $0.kind == .addition }.count
            let deletions = lines.filter { $0.kind == .deletion }.count
            return .ready(FileDiff(
                file: aChangedFile(
                    path: parsed.path,
                    status: hunk.oldCount == 0 ? .added : .modified,
                    insertions: additions,
                    deletions: deletions,
                    estimatedLineCount: lines.count,
                    isViewed: parsed.path == "Sources/Connection/PinStore.swift"
                ),
                hunks: parsed.hunks,
                oldLineCount: max(0, hunk.oldStart + hunk.oldCount - 1),
                newLineCount: hunk.newStart + hunk.newCount - 1,
                isTruncated: false,
                truncationReason: nil
            ))
        }
    }

    private static func comment(path: String, line: Int, quote: String, text: String) -> ReviewComment {
        let position = DiffLinePosition(oldNumber: nil, newNumber: line)
        return ReviewComment(
            anchor: CommentAnchor(file: FileID(repositoryRelativePath: path), first: position, last: position),
            path: path,
            lines: CommentedLines(side: .new, first: line, last: line),
            language: "swift",
            quotedLines: [quote],
            text: text
        )
    }

    private static let patch = """
        diff --git a/Sources/Connection/PairingClient.swift b/Sources/Connection/PairingClient.swift
        --- a/Sources/Connection/PairingClient.swift
        +++ b/Sources/Connection/PairingClient.swift
        @@ -1,8 +1,12 @@
         struct PairingClient {
             let session: Session
        +    let pins: PinStore
        +
             func pair(_ mac: Mac) async throws {
                 let peer = try await mac.handshake()
        -        let policy = Trust.system
        +        let pin = Pin(peer.certificate)
        +        try pins.check(pin, for: mac)
        +        let policy = Trust.pinned(pin)
                 try await session.open(peer, policy)
             }
         }
        diff --git a/Sources/Connection/PinStore.swift b/Sources/Connection/PinStore.swift
        new file mode 100644
        --- /dev/null
        +++ b/Sources/Connection/PinStore.swift
        @@ -0,0 +1,10 @@
        +struct PinStore {
        +    let known: [Mac: Pin]
        +
        +    func check(_ pin: Pin, for mac: Mac) throws {
        +        guard known[mac] == pin else {
        +            throw PairingError.pinMismatch
        +        }
        +    }
        +}
        +
        diff --git a/Tests/Connection/PairingTests.swift b/Tests/Connection/PairingTests.swift
        new file mode 100644
        --- /dev/null
        +++ b/Tests/Connection/PairingTests.swift
        @@ -0,0 +1,10 @@
        +import Testing
        +
        +struct PairingTests {
        +    @Test func acceptsKnownMac() async throws {
        +        let mac = Mac.sample
        +        let client = makeClient(for: mac)
        +        try await client.pair(mac)
        +        #expect(client.session.isConnected)
        +    }
        +}
        """

    private static let presentationPatch = """
        diff --git a/Sources/Connection/Trust.swift b/Sources/Connection/Trust.swift
        --- a/Sources/Connection/Trust.swift
        +++ b/Sources/Connection/Trust.swift
        @@ -1,4 +1,4 @@
         enum Trust {
             case system
        -    case remembered
        +    case pinned(Pin)
         }
        diff --git a/Tests/Connection/PinStoreTests.swift b/Tests/Connection/PinStoreTests.swift
        new file mode 100644
        --- /dev/null
        +++ b/Tests/Connection/PinStoreTests.swift
        @@ -0,0 +1,11 @@
        +import Testing
        +
        +struct PinStoreTests {
        +    @Test func rejectsRotatedPin() throws {
        +        let mac = Mac.sample
        +        let pins = PinStore(known: [mac: .first])
        +        #expect(throws: PairingError.pinMismatch) {
        +            try pins.check(.rotated, for: mac)
        +        }
        +    }
        +}
        """
}

private struct StorePresentation: View {
    let icon: UIImage
    let light: PresentationScreens
    let dark: PresentationScreens
    let split: PresentationSplit

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.09, blue: 0.19), Color(red: 0.11, green: 0.21, blue: 0.37)],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
            RadialGradient(
                colors: [Color(red: 0.34, green: 0.57, blue: 0.91).opacity(0.55), .clear],
                center: .trailing,
                startRadius: 80,
                endRadius: 870
            )
            VStack(alignment: .leading, spacing: 32) {
                HStack(spacing: 14) {
                    Image(uiImage: icon)
                        .resizable()
                        .frame(width: 49, height: 49)
                    Text("Granita")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Color(red: 0.71, green: 0.83, blue: 1))
                }
                Text("Review code\naway from\nyour desk.")
                    .font(.system(size: 78, weight: .bold))
                    .tracking(-4)
                    .lineSpacing(-2)
                    .foregroundStyle(.white)
                Text("Read diffs and send feedback to your\nagent from iPhone, iPad, or Mac.")
                    .font(.system(size: 25))
                    .foregroundStyle(Color(red: 0.79, green: 0.86, blue: 0.97))
                    .lineSpacing(7)
            }
            .padding(.leading, 92)
            .padding(.top, 169)

            light.overlay {
                dark.clipShape(PresentationDarkHalf(split: split))
            }
            .compositingGroup()
            .shadow(color: .black.opacity(0.48), radius: 30, x: 0, y: 18)
        }
        .frame(width: 1600, height: 900)
    }
}

private struct PresentationScreens: View {
    let phone: UIImage
    let mac: UIImage
    let appearance: ColorScheme

    var body: some View {
        ZStack {
            macWindow
                .position(x: 1166, y: 431)
            device(phone, width: 250, cornerRadius: 32)
                .position(x: 820, y: 546)
        }
        .frame(width: 1600, height: 900)
    }

    private var macWindow: some View {
        VStack(spacing: 0) {
            Text("Granita")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(appearance == .dark ? Color.white.opacity(0.82) : Color.black.opacity(0.74))
                .frame(maxWidth: .infinity)
                .frame(height: 31)
                .overlay(alignment: .leading) {
                    HStack(spacing: 6) {
                        Circle().fill(.red)
                        Circle().fill(.yellow)
                        Circle().fill(.green)
                    }
                    .frame(width: 39, height: 9)
                    .padding(.leading, 14)
                }
            Image(uiImage: mac)
                .resizable()
                .scaledToFit()
        }
        .frame(width: 765)
        .background(appearance == .dark ? Color(white: 0.15) : Color(white: 0.91))
        .clipShape(.rect(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .strokeBorder(.white.opacity(0.28), lineWidth: 1)
        }
    }

    private func device(_ image: UIImage, width: CGFloat, cornerRadius: CGFloat) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .clipShape(.rect(cornerRadius: cornerRadius - 6))
            .padding(7)
            .background(Color(red: 0.06, green: 0.08, blue: 0.13), in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(.white.opacity(0.26), lineWidth: 1)
            }
    }
}

private enum PresentationSplit: String, CaseIterable {
    case diagonal = "presentation-diagonal"
    case zigzag = "presentation"
}

private struct PresentationDarkHalf: Shape {
    let split: PresentationSplit

    func path(in rect: CGRect) -> Path {
        let boundary: [CGPoint]
        switch split {
        case .diagonal:
            boundary = [CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 0.24)]
        case .zigzag:
            // The join is inside the phone's right bezel. Both cuts share the same slope.
            let phoneAtBezel = CGPoint(x: 0.5925, y: 0.478)
            let macEnd = CGPoint(x: 1, y: 0.18)
            let rise: CGFloat = 0.363 / 0.338
            boundary = [
                CGPoint(x: phoneAtBezel.x - (1 - phoneAtBezel.y) / rise, y: 1),
                phoneAtBezel,
                CGPoint(x: phoneAtBezel.x, y: macEnd.y + (macEnd.x - phoneAtBezel.x) * rise),
                macEnd
            ]
        }
        return Path { path in
            path.addLines(boundary.map { point in
                CGPoint(x: rect.minX + rect.width * point.x, y: rect.minY + rect.height * point.y)
            })
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
