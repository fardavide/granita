import Foundation

/// The golden corpus in `Fixtures/`, generated from the real `git` binary by
/// `Scripts/make-fixture-repo.sh` and committed so the parser suite runs on a machine without git.
enum Fixture {

    /// Decoded as UTF-8 without normalisation, because the corpus carries a decomposed combining
    /// mark and CRLF endings and both have to reach the assertions intact.
    static func text(_ name: String) throws -> String {
        String(decoding: try bytes(name), as: UTF8.self)
    }

    static func bytes(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: nil,
            subdirectory: "Fixtures"
        ) else {
            throw FixtureError.notInTheBundle(name)
        }
        return try Data(contentsOf: url)
    }
}

enum FixtureError: Error {
    case notInTheBundle(String)
}
