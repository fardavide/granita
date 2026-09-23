import SwiftUI

import ClientViewerDomain

/// How big the code is drawn, in the two halves issue #106 splits it into.
///
/// **Two groups, two segments each, and a stepper under the second.** Design calls 10 and 11. One
/// setting was rejected because the two questions are not the same one: unified is about
/// **legibility** — how small the reader will go, with about 49 characters either way — and split is
/// about **width**, where every point costs about two characters a side from a number that starts at
/// 22. A single number makes the reader pay for one in the other.
///
/// **Every footer is in characters, because points are what you set and characters are what you
/// get.** A numeric stepper with no readout asks somebody to predict a monospaced grid from a point
/// size; quoting both devices' numbers is arithmetic about a screen that is not here.
///
/// **The split group carries the two sentences the diff screen cannot say to a sighted reader.** A
/// disabled toolbar item can hold a tooltip on a Mac and a VoiceOver hint anywhere, and neither of
/// those is a phone reader looking at a dimmed glyph — so the reason lives here as well, which is
/// also the only place they can act on it.
public struct CodeSizeView: View {

    private let readout: CodeSizeReadout
    private let onChoose: (CodeSize) -> Void

    public init(readout: CodeSizeReadout, onChoose: @escaping (CodeSize) -> Void) {
        self.readout = readout
        self.onChoose = onChoose
    }

    public var body: some View {
        Form {
            unifiedSection
            splitSection
        }
        .navigationTitle("Code size")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - The two groups

    private var unifiedSection: some View {
        Section {
            segments(
                isCustom: readout.unified.isCustom,
                onChoose: { onChoose(readout.choosing(unified: $0)) }
            )
            .accessibilityLabel("Unified scroll code size")
            if readout.unified.isCustom {
                stepper(
                    points: readout.unified.pointSize,
                    onChoose: { onChoose(CodeSize(unified: .custom($0), split: readout.split.choice)) }
                )
            }
        } header: {
            Text("Unified scroll")
        } footer: {
            // **`inflect:` rather than a singular branch**, and that is a coverage decision as much
            // as a copy one: one character a line is reachable on a Mac window dragged far enough,
            // and a ternary no baseline renders is a region nothing holds us to. The platform
            // already knows how to agree a noun with a number.
            Text("\(points(readout.unified.pointSize)) — ^[\(readout.unified.characters) character](inflect: true) a line on this device.")
        }
    }

    /// **The group that has something to explain**, and the two things it may have to say are
    /// different in kind: one is a size this screen chose for the reader, the other is a layout they
    /// have lost. Both are stated after the count rather than instead of it, so the number the
    /// sentence is about is always on screen beside it.
    private var splitSection: some View {
        Section {
            segments(
                isCustom: readout.split.isCustom,
                onChoose: { onChoose(readout.choosing(split: $0)) }
            )
            .accessibilityLabel("Side by side code size")
            if readout.split.isCustom {
                stepper(
                    points: readout.split.pointSize,
                    onChoose: { onChoose(CodeSize(unified: readout.unified.choice, split: .custom($0))) }
                )
            }
        } header: {
            Text("Side by side")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(points(readout.split.pointSize)) — ^[\(readout.split.characters) character](inflect: true) a side on this device.")
                // Absent rather than reworded when nothing was held back, which is most readers:
                // a sentence explaining a clamp that did not happen is noise on a screen whose whole
                // job is a number.
                if let asked = readout.heldBackFrom {
                    Text(
                        "Your text size asks for \(points(asked)), held at \(points(readout.split.pointSize)) "
                            + "so two columns still fit. Two columns need \(SplitBlockLayout.floorCharacters) "
                            + "characters a side."
                    )
                }
                // **The lever first and the consequence second**, because the other order asks the
                // reader to act on an instruction they have not been given yet.
                if let refusal = readout.refusal {
                    Text("\(refusal.sentence). Side by Side stays off until you do.")
                }
            }
        }
    }

    // MARK: - The two controls

    /// **A segmented control whose segments are the two answers**, which is the shape the comment
    /// labels row above already uses: a popup menu would hide one of two options behind a tap.
    private func segments(isCustom: Bool, onChoose: @escaping (Bool) -> Void) -> some View {
        Picker("", selection: Binding(get: { isCustom }, set: onChoose)) {
            Text("Follow system").tag(false)
            Text("Custom").tag(true)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    /// **Absent under *Follow system* rather than disabled**, which is this project's first permitted
    /// answer: a stepper the reader can see the figure in but cannot move is a control asking a
    /// question the segment above it has already answered.
    private func stepper(points: CGFloat, onChoose: @escaping (CGFloat) -> Void) -> some View {
        Stepper(
            value: Binding(get: { points }, set: onChoose),
            in: CodeSize.smallest...CodeSize.largest,
            step: 1
        ) {
            HStack {
                Text("Size")
                Spacer(minLength: 8)
                Text(self.points(points))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: -

    private func points(_ size: CGFloat) -> String {
        "\(Int(size)) pt"
    }
}
