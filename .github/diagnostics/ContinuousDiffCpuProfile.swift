import Foundation
import QuartzCore
import Testing
import os

// Copied into the snapshot target only after the required suite fails. Its diagnostic build
// has separate source provenance and never replaces required enumeration or coverage receipts.
extension ContinuousDiffCollapseInteractionTests {
    @Test
    func temporarySynchronizedCiCpuProfile() async throws {
        let metadata = CiCollapseProfileMetadata(
            processId: ProcessInfo.processInfo.processIdentifier,
            bundleId: try #require(Bundle.main.bundleIdentifier),
            uptime: ProcessInfo.processInfo.systemUptime,
            wallTime: Date().timeIntervalSince1970
        )
        let readyUrl = URL(filePath: "/private/tmp/granita-ci-collapse-profile-20261026.ready.json")
        let armedPath = "/private/tmp/granita-ci-collapse-profile-20261026.armed"
        try #require(FileManager.default.fileExists(atPath: readyUrl.path) == false, "Profile ready path must be fresh")
        try #require(FileManager.default.fileExists(atPath: armedPath) == false, "Profile arm path must be fresh")
        try JSONEncoder().encode(metadata).write(to: readyUrl, options: .atomic)
        let deadline = ContinuousClock.now.advanced(by: .seconds(120))
        while FileManager.default.fileExists(atPath: armedPath) == false {
            try #require(ContinuousClock.now < deadline, "Time Profiler was not armed before the setup deadline")
            try await Task.sleep(for: .milliseconds(10))
        }

        do {
            os_signpost(.begin, log: ciCollapseProfileLog, name: "CiPlainCollapse")
            defer { os_signpost(.end, log: ciCollapseProfileLog, name: "CiPlainCollapse") }
            print("[ci-collapse-profile-phase] phase=plain pid=\(metadata.processId) uptime=\(ProcessInfo.processInfo.systemUptime) monotonic=\(CACurrentMediaTime()) wall=\(Date().timeIntervalSince1970)")
            try await `given a pinned file when collapsed then the viewport and successor header arrive in one coherent motion`(
                collapse: .viewed,
                fixture: .plain
            )
        }
        do {
            os_signpost(.begin, log: ciCollapseProfileLog, name: "CiDenseCollapse")
            defer { os_signpost(.end, log: ciCollapseProfileLog, name: "CiDenseCollapse") }
            print("[ci-collapse-profile-phase] phase=dense pid=\(metadata.processId) uptime=\(ProcessInfo.processInfo.systemUptime) monotonic=\(CACurrentMediaTime()) wall=\(Date().timeIntervalSince1970)")
            try await `given a pinned file when collapsed then the viewport and successor header arrive in one coherent motion`(
                collapse: .manual,
                fixture: .denseWordDiffSuccessor
            )
        }
    }
}

private let ciCollapseProfileLog = OSLog(subsystem: "dev.fardavide.granita.collapse-profile", category: "PointsOfInterest")

private struct CiCollapseProfileMetadata: Encodable {
    let processId: Int32
    let bundleId: String
    let uptime: Double
    let wallTime: Double
}
