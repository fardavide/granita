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
//   Ui            SwiftUI views only, over Domain for the model types they render. The INNER of
//                 the two view layers: it owns no view models and depends on no Presentation.
//   Presentation  view models, mappers and screen composition, over its feature's Ui and Domain.
//                 Never a Data target.
//
// Presentation depends on Ui, not the other way round. A Ui target is a vocabulary of stateless
// views that take what they render and report what happened; Presentation owns the state and
// arranges them into screens. That direction is what keeps a view reusable by more than the one
// screen that first needed it, and it is why a Ui target has no test target — there is nothing in
// one a test would want to reach.
//
// Three targets are composition roots and are exempt, because wiring implementations into
// protocols is their entire job: ClientAppPresentation, ServerMacPresentation and the
// granita-server executable. Nothing depends on them, which is what makes the exemption safe.
//
// Exactly three external dependencies, each pinned to exactly one target. No other target may
// declare an external product.

/// Every target compiles in Swift 6 language mode; strict concurrency checking is `complete` there.
let swift6 = SwiftSetting.swiftLanguageMode(.v6)

/// Ui and Presentation are main-actor by default: both drive SwiftUI, and saying so once per target
/// beats annotating every type in them.
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
        .library(name: "ClientAppPresentation", targets: ["ClientAppPresentation"]),
        .library(name: "ServerMacPresentation", targets: ["ServerMacPresentation"]),
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
        .package(url: "https://github.com/swiftlang/swift-subprocess.git", from: "1.0.0"),
        // NOT a fourth dependency in substance. It is already in the resolved graph — Hummingbird
        // pulls it — and SPEC §8 mandates running on a NIOTSEventLoopGroup, because that is the
        // only bootstrap that can bind and advertise Bonjour in one operation. SwiftPM simply
        // requires the product be named before a target may import it, and Hummingbird does not
        // re-export it.
        .package(url: "https://github.com/apple/swift-nio-transport-services.git", from: "1.28.0")
    ],
    targets: [

        // MARK: - Core — pure logic, compiles for iOS and macOS alike

        // Not in the spec's §3 tree. The spec asks for the product name, bundle-identifier prefix,
        // Bonjour service type, URL scheme and Application Support directory to live in "a single
        // Branding.swift", and both units need them — so it is a Core module rather than a copy on
        // each side.
        .target(
            name: "CoreBrandingDomain",
            path: "Core/Branding/Domain",
            swiftSettings: [swift6]
        ),

        .testTarget(
            name: "CoreBrandingDomainTests",
            dependencies: ["CoreBrandingDomain"],
            path: "Core/Branding/DomainTests",
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
        .target(
            name: "ClientConnectionUi",
            dependencies: ["ClientConnectionDomain", "CoreBrandingDomain"],
            path: "Client/Connection/Ui",
            swiftSettings: [swift6, mainActorByDefault]
        ),
        .target(
            name: "ClientConnectionPresentation",
            dependencies: ["ClientConnectionUi", "ClientConnectionDomain", "CoreBrandingDomain"],
            path: "Client/Connection/Presentation",
            swiftSettings: [swift6, mainActorByDefault]
        ),
        .testTarget(
            name: "ClientConnectionPresentationTests",
            dependencies: ["ClientConnectionPresentation", "ClientConnectionDomain"],
            path: "Client/Connection/PresentationTests",
            swiftSettings: [swift6, mainActorByDefault]
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
            name: "ClientWorktreesUi",
            dependencies: ["ClientWorktreesDomain", "CoreDiffDomain"],
            path: "Client/Worktrees/Ui",
            swiftSettings: [swift6, mainActorByDefault]
        ),
        .target(
            name: "ClientWorktreesPresentation",
            dependencies: ["ClientWorktreesUi", "ClientWorktreesDomain", "CoreDiffDomain"],
            path: "Client/Worktrees/Presentation",
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
            name: "ClientViewerUi",
            dependencies: [
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
        .target(
            name: "ClientViewerPresentation",
            dependencies: ["ClientViewerUi", "ClientViewerDomain", "CoreDiffDomain", "CoreTreeDomain"],
            path: "Client/Viewer/Presentation",
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
            name: "ClientAppPresentation",
            dependencies: [
                "CoreBrandingDomain",
                "CoreDiffDomain",
                "ClientConnectionDomain",
                "ClientConnectionData",
                "ClientConnectionUi",
                "ClientConnectionPresentation",
                "ClientWorktreesPresentation",
                "ClientWorktreesData",
                "ClientViewerPresentation",
                "ClientViewerData"
            ],
            path: "Client/App/Presentation",
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
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "NIOTransportServices", package: "swift-nio-transport-services")
            ],
            path: "Server/Api/Presentation",
            swiftSettings: [swift6]
        ),
        .testTarget(
            name: "ServerApiPresentationTests",
            dependencies: [
                "ServerApiPresentation",
                "ServerWorktreesDomain",
                "ServerStoreDomain",
                "CoreBrandingDomain",
                "CoreDiffDomain",
                // Same package as Hummingbird itself, so this adds no dependency: it is the
                // in-process test client, which exercises the real router without binding a port.
                .product(name: "HummingbirdTesting", package: "hummingbird")
            ],
            path: "Server/Api/PresentationTests",
            swiftSettings: [swift6]
        ),

        .target(
            name: "ServerMacUi",
            dependencies: ["CoreBrandingDomain", "ServerWorktreesDomain", "ServerStoreDomain", "CoreDiffDomain"],
            path: "Server/Mac/Ui",
            swiftSettings: [swift6, mainActorByDefault]
        ),

        // Composition root for the menu bar app: the only Server target that may see a Data target.
        .target(
            name: "ServerMacPresentation",
            dependencies: [
                "CoreBrandingDomain",
                "CoreDiffDomain",
                "ServerMacUi",
                "ServerApiPresentation",
                "ServerWorktreesDomain",
                "ServerStoreDomain",
                "ServerStoreData",
                "ServerGitDomain",
                "ServerGitData",
                "ServerSessionsData",
                "ServerWatchData"
            ],
            path: "Server/Mac/Presentation",
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
