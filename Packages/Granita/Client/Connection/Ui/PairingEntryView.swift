import SwiftUI

import ClientConnectionDomain

/// Where a Mac's row leads, and the only screen in this flow that is about the other machine.
///
/// **It exists for the sentence, not for the choice.** The obvious build opens the viewfinder the
/// instant a Mac is tapped, and drawn in sequence that does not survive: at the moment the reader
/// taps a Mac, the Mac is not showing a code yet — the QR only exists once somebody chooses *Pair a
/// device* in the menu bar. A viewfinder opening onto a desktop with nothing on it says nothing
/// while asking for the one thing that has not been done, so this screen says it instead.
///
/// Stateless. It renders the Mac it was given and reports which credential the reader chose, so both
/// buttons can be put in front of a camera without a network or a Mac.
///
/// **No "or enter a code" link**, and the two buttons are the same width, weight and height: a link
/// under a button is a confession that one of the two is for people who failed, and the six words
/// are not that. Camera first, which is design §5.6's asymmetry carried in the cheapest of the two
/// places it is carried — the QR is the only credential that arrives with a key.
public struct PairingEntryView: View {

    /// What both credentials are offered at, because the design's whole argument for the order is
    /// that the second one is not a footnote. One measurement, so they cannot drift — and the
    /// scanner's own six-word button reads it too, since that is this same button one screen in.
    ///
    /// A minimum rather than a height: the review was run at Dynamic Type xxLarge as well as Large,
    /// and a fixed 50 clips the larger of the two.
    static let credentialButtonHeight: CGFloat = 50

    private let macName: String
    private let address: ServerAddress?
    private let onScanCode: () -> Void
    private let onEnterWords: () -> Void

    /// `address` is absent until something has resolved one. A browse result is an identity rather
    /// than a location — the Mac binds a service endpoint and the system picks the port — so the
    /// line at the bottom appears when the address is known and is **absent rather than guessed**
    /// when it is not.
    public init(
        macName: String,
        address: ServerAddress?,
        onScanCode: @escaping () -> Void,
        onEnterWords: @escaping () -> Void
    ) {
        self.macName = macName
        self.address = address
        self.onScanCode = onScanCode
        self.onEnterWords = onEnterWords
    }

    public var body: some View {
        VStack(spacing: 12) {
            // The unavailable-content view takes the flexible space, which puts the instruction in
            // the middle of the screen and leaves the two credentials sitting on the bottom edge —
            // the shape the frame draws, in the same idiom as every other empty state in the app.
            ContentUnavailableView {
                Label("Pair with this Mac", systemImage: "macbook.and.iphone")
            } description: {
                Text(
                    """
                    Open Granita in your Mac's menu bar and choose “Pair a device”. \
                    It shows a QR code and six words. Either one pairs this iPhone.
                    """
                )
            }

            Button(action: onScanCode) {
                Label("Scan the QR Code", systemImage: "qrcode.viewfinder")
                    .frame(maxWidth: .infinity, minHeight: Self.credentialButtonHeight)
            }
            .buttonStyle(.borderedProminent)

            Button(action: onEnterWords) {
                Label("Enter the Six Words", systemImage: "keyboard")
                    .frame(maxWidth: .infinity, minHeight: Self.credentialButtonHeight)
            }
            .buttonStyle(.bordered)

            if let address {
                // Verbatim, because it is a machine's address rather than a sentence: a port put
                // through a number format picks up a grouping separator and reads as a quantity.
                Text(verbatim: "\(address.host):\(address.port)")
                    .font(.caption2)
                    .monospaced()
                    .foregroundStyle(.tertiary)
                    // Middle, because both ends carry: the Mac's name is at the front and the port
                    // it is answering on is at the back.
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .navigationTitle(macName)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
