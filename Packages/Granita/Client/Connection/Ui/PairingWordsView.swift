import SwiftUI

import CorePairingDomain

/// One field, and an echo in the Mac's own format.
///
/// **The echo is the whole idea.** The reader is copying a phrase off a screen across the room, so
/// the line beneath the field shows what the phone understood, joined by middle dots exactly as the
/// Mac joins them: comparing two lines character for character is a different and far easier task
/// than proofreading your own typing.
///
/// Stateless — the phrase lives in the model, and what was made of it arrives already read. The word
/// list is contract and lives in `Core`, so the parsing happens where the list is and this screen
/// only renders the answer.
///
/// **The field corrects nothing.** The server lowercases and accepts spaces, hyphens, middle dots
/// and the dash iOS types whether or not anyone meant to, so there is nothing here to fix, and the
/// capitalised first word everyone types is a keystroke the normaliser eats rather than an error to
/// catch.
public struct PairingWordsView: View {

    private let macName: String
    private let spokenWords: [String]
    private let unknownWord: String?
    private let onPair: () -> Void

    @Binding private var typedWords: String

    @FocusState private var isTypingWords: Bool

    public init(
        macName: String,
        typedWords: Binding<String>,
        spokenWords: [String],
        unknownWord: String?,
        onPair: @escaping () -> Void
    ) {
        self.macName = macName
        _typedWords = typedWords
        self.spokenWords = spokenWords
        self.unknownWord = unknownWord
        self.onPair = onPair
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("The six words on your Mac")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Under the QR code. Spaces, hyphens or the middle dots — type it however you read it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            field
                .padding(.top, 22)

            echo
                .padding(.top, 8)

            if let unknownWord {
                // Only ever the first, and only ever a settled word: the reader is told which word
                // to look at rather than accused of the one they are three keystrokes from
                // finishing. It costs a wasted round trip, and a wasted round trip is a fifth of
                // the rate limit.
                Label(
                    "“\(unknownWord)” is not one of the words. Check it against your Mac.",
                    systemImage: "exclamationmark.circle"
                )
                .font(.footnote)
                .foregroundStyle(.red)
                .padding(.top, 10)
            }

            Spacer(minLength: 20)

            // §5.6, and the only place the asymmetry between the two credentials is written on a
            // screen. A true sentence about a pin rather than a revival of the plaintext warning
            // 0.0.7 retired — the connection is TLS either way.
            Text(
                """
                The QR code also carries your Mac's key. Typed words trust the Mac that answers, \
                so use them on a network you trust.
                """
            )
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.bottom, 14)

            // Six words entered lights it and nothing else: no count in the label, no ready badge.
            // The button turning blue is the whole announcement, and the count above says why it has
            // not yet.
            Button(action: onPair) {
                // The measure goes on the label rather than on the button: a frame outside a
                // bordered style centres a small button in a wide space instead of widening it.
                Text("Pair")
                    .frame(maxWidth: .infinity, minHeight: PairingEntryView.credentialButtonHeight)
            }
            .buttonStyle(.borderedProminent)
            .disabled(spokenWords.count != SpokenWords.wordsInACode)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(macName)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// Monospaced at body size, to match the 13pt mono the Mac shows the words in.
    ///
    /// **One line, because Go has to do something.** A field on a vertical axis takes the Return key
    /// as a newline and never submits, so `submitLabel(.go)` over one draws the key that reads as
    /// the action and is not it — the shape of dead control this project is named for. §5 asks for
    /// one field with Go on it, and this is the version of that which works.
    ///
    /// What the reader compares against the Mac is the echo underneath rather than their own
    /// typing, and that line wraps; the field only has to hold what they typed, which is why
    /// scrolling it sideways costs nothing the design was relying on.
    ///
    /// **Autocorrection off matters more than it looks**, and it is doing two jobs: it stops iOS
    /// turning a word from a 128-word list into an English word that is not in it, and — because the
    /// smart-punctuation traits follow the autocorrection trait rather than having a SwiftUI
    /// modifier of their own — it is also what stops a typed hyphen becoming an en dash. The
    /// normaliser accepts that dash anyway, because paste is a path no field setting reaches — and
    /// the same paste is why it accepts a line ending.
    private var field: some View {
        TextField("six words", text: $typedWords)
            .monospaced()
            .autocorrectionDisabled()
            .focused($isTypingWords)
            // On appear rather than on tap: this screen exists to be typed into, and a keyboard the
            // reader has to summon is a keyboard that arrives after they have looked back at the Mac.
            .defaultFocus($isTypingWords, true)
            .submitLabel(.go)
            .onSubmit(onPair)
            .textFieldStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.quaternary, in: .rect(cornerRadius: 11))
            #if !os(macOS)
            .textInputAutocapitalization(.never)
            #endif
    }

    /// What the phone understood, above what is left to type.
    private var echo: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            // Verbatim and joined here rather than assembled from views: this line exists to be read
            // against the Mac's, so it has to be one string in one shape.
            Text(verbatim: spokenWords.joined(separator: " · "))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(spokenWords.count, format: .number) of \(SpokenWords.wordsInACode, format: .number)")
                // The count is what the reader is checking against, so it is the half of this line
                // that never wraps or truncates.
                .fixedSize()
        }
        .font(.caption)
        .monospaced()
        .foregroundStyle(.secondary)
    }
}
