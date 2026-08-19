import Foundation
import Testing

@testable import CoreBrandingDomain

@Suite("Branding")
struct BrandingTests {

    /// `serverVersion` reads the bundle when there is one and falls back to a literal for
    /// `swift run`, which has no bundle. That literal is the single place the marketing version is
    /// repeated outside `project.yml`, and a drift between the two ships a mislabelled `/v1/health`
    /// — which is exactly the payload a phone uses to decide whether to refuse to pair.
    ///
    /// Locating the manifest through `#filePath` rather than the working directory, because a test
    /// runner's cwd is not something to rely on.
    @Test
    func `given the manifest when reading the fallback version then they agree`() throws {
        // given
        let manifest = URL(filePath: #filePath)
            .deletingLastPathComponent()   // …/Core/Branding/DomainTests
            .deletingLastPathComponent()   // …/Core/Branding
            .deletingLastPathComponent()   // …/Core
            .deletingLastPathComponent()   // …/Packages/Granita
            .deletingLastPathComponent()   // …/Packages
            .deletingLastPathComponent()   // the repository root
            .appending(path: "project.yml")

        // when
        let declared = try String(contentsOf: manifest, encoding: .utf8)
            .split(separator: "\n")
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("MARKETING_VERSION:") else { return nil }
                return trimmed.dropFirst("MARKETING_VERSION:".count).trimmingCharacters(in: .whitespaces)
            }
            .first

        // then
        #expect(declared == Branding.fallbackServerVersion)
    }

    @Test
    func `when reading the bonjour service type then it is a well formed dns-sd label`() {
        // given - when
        let type = Branding.bonjourServiceType

        // then — the label is capped at fifteen characters by DNS-SD, and both affixes are required.
        #expect(type.hasPrefix("_"))
        #expect(type.hasSuffix("._tcp"))
        let label = type.dropFirst().prefix(while: { $0 != "." })
        #expect(label.count <= 15)
    }
}
