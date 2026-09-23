import SwiftUI
import Testing

import ClientViewerDomain

@testable import ClientSettingsPresentation

/// SwiftUI's text sizes, as the domain's own.
///
/// **The one thing worth asserting is that it is total and in order.** A mapping that dropped a case
/// onto Large would leave the code at eleven points for a reader who had asked for more, and the
/// `@unknown default` it carries — `DynamicTypeSize` is another module's non-frozen enum — is
/// exactly the arm that would swallow a silent hole.
@Suite("Reader text size")
struct ReaderTextSizeMappingTests {

    @Test(arguments: zip(DynamicTypeSize.allCases, ReaderTextSize.allCases))
    func `given a system text size when it is mapped then it is the step at the same position`(
        system: DynamicTypeSize,
        expected: ReaderTextSize
    ) {
        // given - when
        let mapped = ReaderTextSize(system)

        // then — zipped rather than listed, so a case added to either list without the other fails
        // the count assertion below rather than passing quietly.
        #expect(mapped == expected)
    }

    @Test
    func `given both lists when they are counted then neither has a case the other does not`() {
        // given - when - then — the guard the zip above cannot give on its own: `zip` stops at the
        // shorter of the two.
        #expect(DynamicTypeSize.allCases.count == ReaderTextSize.allCases.count)
    }

    @Test
    func `given the default text size when it is mapped then it is Large`() {
        // given - when - then — the size every measurement in design §4 was taken at, and the one an
        // unknown future case falls back to.
        #expect(ReaderTextSize(.large) == .default)
        #expect(ReaderTextSize(.large).stepsFromLarge == 0)
    }
}
