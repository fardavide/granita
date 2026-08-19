// swift-tools-version: 6.2

import PackageDescription

// Granita's module graph. A target's module name is its directory path with the slashes removed
// (`Client/Viewer/Data` -> `import ClientViewerData`), so the tree on disk and the import list in
// a file say the same thing.
//
// The layer rules live here rather than in a review checklist, because a dependency a target does
// not declare is a dependency that does not compile:
//
//   Domain        other Domain targets and Foundation. No frameworks, no I/O.
//   Data          Domain targets, plus at most one external infra dependency.
//   Presentation  Domain targets and Observation. Never SwiftUI, never a Data target.
//   Ui            its own Presentation, Domain for model types, and SwiftUI. Never a Data target.
//
// Three targets are composition roots and are exempt, because wiring implementations into
// protocols is their entire job: ClientAppUi, ServerMacUi and the granita-server executable.
//
// Exactly three external dependencies, each pinned to exactly one target. No other target may
// declare an external product.

/// Every target compiles in Swift 6 language mode; strict concurrency checking is `complete` there.
let swift6 = SwiftSetting.swiftLanguageMode(.v6)

/// Presentation and Ui targets are main-actor by default: a view model that drives SwiftUI is
/// main-actor in practice, and saying so once per target beats annotating every type.
let mainActorByDefault = SwiftSetting.defaultIsolation(MainActor.self)

let package = Package(
    name: "Granita",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        // The two app shells link one product each; `granita-server` is how the backend runs,
        // is tested and is recovered without Xcode in the loop.
        .library(name: "ClientAppUi", targets: ["ClientAppUi"]),
        .library(name: "ServerMacUi", targets: ["ServerMacUi"]),
        .executable(name: "granita-server", targets: ["ServerCliMain"])
    ],
    dependencies: [
        // Hummingbird 2 — async/await native, no EventLoopFuture legacy, and its
        // `BindAddress.nwEndpoint` routes through NIOTSListenerBootstrap so listening and Bonjour
        // advertising happen in one bind rather than fighting over the port.
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.26.0"),
        // Highlightr, not HighlightSwift: it builds the attributed string itself, with no
        // main-thread-only HTML importer and no input trimming.
        .package(url: "https://github.com/raspu/Highlightr.git", from: "2.3.0"),
        // swift-subprocess — `Foundation.Process` deadlocks when a child outwrites the pipe
        // buffer unless both streams drain concurrently, and it hands the child our own process
        // group, which makes timeout handling dangerous.
        .package(url: "https://github.com/swiftlang/swift-subprocess.git", from: "1.0.0")
    ],
    targets: [

        // MARK: - Core — pure logic, compiles for iOS and macOS alike

        // Not in the spec's §3 tree. The spec asks for the product name, bundle-identifier
        // prefix, Bonjour service type, URL scheme and Application Support directory to live in
        // "a single Branding.swift", and both units need them — so it is a Core module rather
        // than a copy on each side.
        .target(
            name: "CoreBrandingDomain",
            path: "Core/Branding/Domain",
            swiftSettings: [swift6]
        ),

        .target(
            name: "CoreDiffDomain",
            path: "Core/Diff/Domain",
            swiftSettings: [swift6]
        ),
        .testTarget(
            name: "CoreDiffDomainTests",
            dependencies: ["CoreDiffDomain"],
            path: "Core/Diff/DomainTests",
            resources: [.copy("Fixtures")],
            swiftSettings: [swift6]
        ),

        .target(
            name: "CoreTreeDomain",
            dependencies: ["CoreDiffDomain"],
            path: "Core/Tree/Domain",
            swiftSettings: [swift6]
        ),
        .testTarget(
            name: "CoreTreeDomainTests",
            dependencies: ["CoreTreeDomain", "CoreDiffDomain"],
            path: "Core/Tree/DomainTests",
            swiftSettings: [swift6]
        ),

        // MARK: - Client — iOS and iPadOS

        .target(
            name: "ClientConnectionDomain",
            dependencies: ["CoreBrandingDomain", "CoreDiffDomain"],
            path: "Client/Connection/Domain",
            swiftSettings: [swift6]
        ),
        .target(
            name: "ClientConnectionData",
            dependencies: ["CoreBrandingDomain", "ClientConnectionDomain", "CoreDiffDomain"],
            path: "Client/Connection/Data",
            swiftSettings: [swift6]
        ),
        .testTarget(
            name: "ClientConnectionDataTests",
            dependencies: ["ClientConnectionData", "ClientConnectionDomain", "CoreDiffDomain"],
            path: "Client/Connection/DataTests",
            swiftSettings: [swift6]
        ),

        .target(
            name: "ClientWorktreesDomain",
            dependencies: ["CoreDiffDomain"],
            path: "Client/Worktrees/Domain",
            swiftSettings: [swift6]
        ),
        .target(
            name: "ClientWorktreesData",
            dependencies: ["ClientWorktreesDomain", "ClientConnectionDomain", "CoreDiffDomain"],
            path: "Client/Worktrees/Data",
            swiftSettings: [swift6]
        ),
        .target(
            name: "ClientWorktreesPresentation",
            dependencies: ["ClientWorktreesDomain", "CoreDiffDomain"],
            path: "Client/Worktrees/Presentation",
            swiftSettings: [swift6, mainActorByDefault]
        ),
        .target(
            name: "ClientWorktreesUi",
            dependencies: ["ClientWorktreesPresentation", "ClientWorktreesDomain", "CoreDiffDomain"],
            path: "Client/Worktrees/Ui",
            swiftSettings: [swift6, mainActorByDefault]
        ),
        .testTarget(
            name: "ClientWorktreesDomainTests",
            dependencies: ["ClientWorktreesDomain", "CoreDiffDomain"],
            path: "Client/Worktrees/DomainTests",
            swiftSettings: [swift6]
        ),
        .testTarget(
            name: "ClientWorktreesPresentationTests",
            dependencies: ["ClientWorktreesPresentation", "ClientWorktreesDomain", "CoreDiffDomain"],
            path: "Client/Worktrees/PresentationTests",
            swiftSettings: [swift6, mainActorByDefault]
        ),

        .target(
            name: "ClientViewerDomain",
            dependencies: ["CoreDiffDomain", "CoreTreeDomain"],
            path: "Client/Viewer/Domain",
            swiftSettings: [swift6]
        ),
        .target(
            name: "ClientViewerData",
            dependencies: ["ClientViewerDomain", "ClientConnectionDomain", "CoreDiffDomain"],
            path: "Client/Viewer/Data",
            swiftSettings: [swift6]
        ),
        .target(
            name: "ClientViewerPresentation",
            dependencies: ["ClientViewerDomain", "CoreDiffDomain", "CoreTreeDomain"],
            path: "Client/Viewer/Presentation",
            swiftSettings: [swift6, mainActorByDefault]
        ),
        .target(
            name: "ClientViewerUi",
            dependencies: [
                "ClientViewerPresentation",
                "ClientViewerDomain",
                "CoreDiffDomain",
                "CoreTreeDomain",
                // Highlighting turns diff text into attributed strings for rendering, which is
                // Ui work. One Highlightr instance per background actor for the app lifetime —
                // its JSContext is not shareable across threads.
                .product(name: "Highlightr", package: "Highlightr")
            ],
            path: "Client/Viewer/Ui",
            swiftSettings: [swift6, mainActorByDefault]
        ),
        .testTarget(
            name: "ClientViewerDomainTests",
            dependencies: ["ClientViewerDomain", "CoreDiffDomain", "CoreTreeDomain"],
            path: "Client/Viewer/DomainTests",
            swiftSettings: [swift6]
        ),
        .testTarget(
            name: "ClientViewerPresentationTests",
            dependencies: ["ClientViewerPresentation", "ClientViewerDomain", "CoreDiffDomain", "CoreTreeDomain"],
            path: "Client/Viewer/PresentationTests",
            swiftSettings: [swift6, mainActorByDefault]
        ),

        // Composition root for the phone: the only Client target that may see a Data target.
        .target(
            name: "ClientAppUi",
            dependencies: [
                "CoreBrandingDomain",
                "ClientConnectionDomain",
                "ClientConnectionData",
                "ClientWorktreesUi",
                "ClientWorktreesData",
                "ClientViewerUi",
                "ClientViewerData",
                "CoreDiffDomain"
            ],
            path: "Client/App/Ui",
            swiftSettings: [swift6, mainActorByDefault]
        ),

        // MARK: - Server — macOS only, free to use macOS-only APIs

        .target(
            name: "ServerGitDomain",
            dependencies: ["CoreDiffDomain"],
            path: "Server/Git/Domain",
            swiftSettings: [swift6]
        ),
        .target(
            name: "ServerGitData",
            dependencies: [
                "ServerGitDomain",
                "CoreDiffDomain",
                .product(name: "Subprocess", package: "swift-subprocess")
            ],
            path: "Server/Git/Data",
            swiftSettings: [swift6]
        ),
        .testTarget(
            name: "ServerGitDataTests",
            dependencies: ["ServerGitData", "ServerGitDomain", "CoreDiffDomain"],
            path: "Server/Git/DataTests",
            swiftSettings: [swift6]
        ),

        .target(
            name: "ServerWorktreesDomain",
            dependencies: ["ServerGitDomain", "CoreDiffDomain", "CoreTreeDomain"],
            path: "Server/Worktrees/Domain",
            swiftSettings: [swift6]
        ),
        .testTarget(
            name: "ServerWorktreesDomainTests",
            dependencies: ["ServerWorktreesDomain", "ServerGitDomain", "CoreDiffDomain"],
            path: "Server/Worktrees/DomainTests",
            swiftSettings: [swift6]
        ),

        .target(
            name: "ServerSessionsData",
            dependencies: ["ServerWorktreesDomain", "CoreDiffDomain"],
            path: "Server/Sessions/Data",
            swiftSettings: [swift6]
        ),
        .testTarget(
            name: "ServerSessionsDataTests",
            dependencies: ["ServerSessionsData", "ServerWorktreesDomain"],
            path: "Server/Sessions/DataTests",
            swiftSettings: [swift6]
        ),

        .target(
            name: "ServerStoreDomain",
            dependencies: ["CoreDiffDomain"],
            path: "Server/Store/Domain",
            swiftSettings: [swift6]
        ),
        .target(
            name: "ServerStoreData",
            dependencies: ["CoreBrandingDomain", "ServerStoreDomain", "CoreDiffDomain"],
            path: "Server/Store/Data",
            swiftSettings: [swift6]
        ),
        .testTarget(
            name: "ServerStoreDataTests",
            dependencies: ["ServerStoreData", "ServerStoreDomain", "CoreDiffDomain"],
            path: "Server/Store/DataTests",
            swiftSettings: [swift6]
        ),

        .target(
            name: "ServerWatchData",
            dependencies: ["ServerWorktreesDomain", "CoreDiffDomain"],
            path: "Server/Watch/Data",
            swiftSettings: [swift6]
        ),

        .target(
            name: "ServerApiPresentation",
            dependencies: [
                "CoreBrandingDomain",
                "ServerWorktreesDomain",
                "ServerStoreDomain",
                "ServerGitDomain",
                "CoreDiffDomain",
                .product(name: "Hummingbird", package: "hummingbird")
            ],
            path: "Server/Api/Presentation",
            swiftSettings: [swift6]
        ),
        .testTarget(
            name: "ServerApiPresentationTests",
            dependencies: ["ServerApiPresentation", "ServerWorktreesDomain", "ServerStoreDomain", "CoreDiffDomain"],
            path: "Server/Api/PresentationTests",
            swiftSettings: [swift6]
        ),

        .target(
            name: "ServerMacPresentation",
            dependencies: ["CoreBrandingDomain", "ServerWorktreesDomain", "ServerStoreDomain", "ServerGitDomain", "CoreDiffDomain"],
            path: "Server/Mac/Presentation",
            swiftSettings: [swift6, mainActorByDefault]
        ),

        // Composition root for the menu bar app: the only Server Ui target, and the only one that
        // may see a Data target.
        .target(
            name: "ServerMacUi",
            dependencies: [
                "CoreBrandingDomain",
                "ServerMacPresentation",
                "ServerApiPresentation",
                "ServerWorktreesDomain",
                "ServerStoreDomain",
                "ServerStoreData",
                "ServerGitDomain",
                "ServerGitData",
                "ServerSessionsData",
                "ServerWatchData",
                "CoreDiffDomain"
            ],
            path: "Server/Mac/Ui",
            swiftSettings: [swift6, mainActorByDefault]
        ),

        // Composition root for the terminal: the same backend the menu bar app embeds, runnable
        // with `swift run granita-server` and no Xcode in the loop.
        .executableTarget(
            name: "ServerCliMain",
            dependencies: [
                "CoreBrandingDomain",
                "ServerApiPresentation",
                "ServerWorktreesDomain",
                "ServerStoreDomain",
                "ServerStoreData",
                "ServerGitDomain",
                "ServerGitData",
                "ServerSessionsData",
                "ServerWatchData",
                "CoreDiffDomain"
            ],
            path: "Server/Cli/Main",
            swiftSettings: [swift6]
        )
    ]
)
