import SwiftUI

import ClientViewerDomain

/// The moment of choosing: every theme, both halves, one tap.
///
/// **A stock grouped list with a checkmark, pushed onto the sheet's own stack.** Each row is the
/// theme's name and its pair drawn exactly as the section draws it — same sample, same two cards, same
/// order — so choosing is comparing the thing you will get rather than reading names and finding out
/// afterwards.
///
/// **A push is right here where it was wrong in the sidebar**: inside the sheet the back button has
/// nothing else to mean. An inline picker was rejected for the room it takes from the receipt above it,
/// and a menu for showing one name at a time and being unable to carry a drawing at all.
///
/// What the rows deliberately do not have: **no per-row captions**, because *Light* and *Dark* under
/// every sample is the same two words once per theme and the cards say it by being white and
/// near-black; **no live lexing and no stylesheet swap**, so the actor keeps the one stylesheet the
/// diff behind the sheet is using; **no Apply and no confirmation**, because choosing is instant and
/// reversible and the diff re-lexes on the way back; **and nothing disabled**.
public struct CodeThemeChooserView: View {

    private let chosen: CodeTheme
    private let onChoose: (CodeTheme) -> Void

    public init(chosen: CodeTheme, onChoose: @escaping (CodeTheme) -> Void) {
        self.chosen = chosen
        self.onChoose = onChoose
    }

    public var body: some View {
        Form {
            Section {
                ForEach(CodeTheme.allCases, id: \.self) { theme in
                    Button { onChoose(theme) } label: {
                        row(for: theme)
                    }
                    // The row is a button so the whole cell is the hit area, and `.plain` is what stops
                    // every word in it turning blue — the name and the samples are content, not a link.
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Theme")
            } footer: {
                Text("The left sample is how code looks in light, the right in dark. Kept on this device.")
            }
        }
        .navigationTitle("Code colours")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: -

    @ViewBuilder
    private func row(for theme: CodeTheme) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Text(theme.displayName)
                    .foregroundStyle(.primary)
                Spacer(minLength: 10)
                // **The one place the word appears**, which is the other half of how the default is
                // told apart: the section marks it in none, because a value the reader can always
                // choose back from a short list needs neither a badge nor a Reset row.
                if theme == .default {
                    Text("Default")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                // Drawn rather than reserved, so an unchosen row spends no width on an empty box — a
                // checkmark column would push three names left for one row's benefit.
                if theme == chosen {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            CodeThemePairView(theme: theme)
        }
        .padding(.vertical, 2)
        // One element per row rather than a name and two pictures: the samples are decorative, so what
        // a screen reader reads is the theme and whether it is the one in use.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(theme.displayName)
        .accessibilityAddTraits(theme == chosen ? [.isButton, .isSelected] : .isButton)
    }
}
