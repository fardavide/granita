import SwiftUI
import Testing

import ClientSettingsUi
import ClientViewerDomain
import CoreComponentsUi

@Suite("Mac reader View menu", .serialized)
@MainActor
struct MacReaderMenuViewSnapshotTests {
    @Test(arguments: Subject.allCases, MacAppearance.all)
    func menu(subject: Subject, appearance: MacAppearance) async throws {
        try await assertReaderSnapshot(
            VStack(alignment: .leading, spacing: 8) {
                MacReaderMenuView(
                    isSideBySide: .constant(subject == .maximum),
                    codeTheme: .constant(.default),
                    codeSize: CodeSizeReadout.Half(
                        choice: subject == .noReader ? .followSystem : .custom(subject.points),
                        pointSize: subject.points,
                        characters: 80
                    ),
                    inspector: subject == .noReader ? nil : ReaderInspectorAction(
                        isPresented: subject == .maximum, toggle: {}
                    ),
                    refreshSidebar: subject == .noReader ? nil : {},
                    refreshDiff: subject == .noReader ? nil : {},
                    onIncreaseCodeSize: {},
                    onDecreaseCodeSize: {},
                    onRestoreCodeSize: {}
                )
            }
            .buttonStyle(.plain)
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading),
            appearance: appearance,
            named: subject.rawValue,
            size: CGSize(width: 360, height: 300)
        )
    }

    enum Subject: String, CaseIterable, Sendable, CustomTestStringConvertible {
        case noReader = "no-reader-system-size"
        case minimum = "reader-minimum-size-inspector-closed"
        case maximum = "reader-maximum-size-inspector-open"

        var testDescription: String { rawValue }
        var points: CGFloat {
            switch self {
            case .noReader: 12
            case .minimum: 8
            case .maximum: 17
            }
        }
    }
}
