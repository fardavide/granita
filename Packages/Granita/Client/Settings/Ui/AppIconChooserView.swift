import SwiftUI

import ClientSettingsDomain

/// The moment of choosing the Home Screen icon: both drawings, one tap.
///
/// **The same shape as the *Code colours* chooser, on purpose** — a stock grouped list with a
/// checkmark, pushed onto the sheet's own stack, each row the thing itself rather than its name. The
/// section's rule applies here too: the reader is choosing a drawing, so every surface shows the
/// drawing.
///
/// **No Apply and no confirmation of our own.** iOS confirms a changed icon with an alert of its own,
/// which is the one feedback this needs; a second one from us would be the same sentence twice.
/// **Nothing is disabled**: both icons are always available where this screen can be reached at all,
/// and on a Mac the row that pushes it is absent.
public struct AppIconChooserView: View {

    private let choice: AppIconChoice
    private let onChoose: (AppIcon) -> Void

    public init(choice: AppIconChoice, onChoose: @escaping (AppIcon) -> Void) {
        self.choice = choice
        self.onChoose = onChoose
    }

    public var body: some View {
        Form {
            Section {
                ForEach(AppIcon.allCases, id: \.self) { icon in
                    Button { onChoose(icon) } label: {
                        row(for: icon)
                            // **Without this, only the drawing and the name answer a tap.** A `.plain`
                            // button is hit only where its label draws, and the spacer between the
                            // name and the checkmark draws nothing, so most of the row was a hole.
                            .contentShape(Rectangle())
                    }
                    // `.plain` keeps the name from turning blue: it is content, not a link.
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Icon")
            } footer: {
                footer
            }
        }
        .navigationTitle("App icon")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: -

    @ViewBuilder
    private func row(for icon: AppIcon) -> some View {
        HStack(spacing: 14) {
            AppIconPreviewView(icon: icon, size: 60)
            Text(icon.displayName)
                .foregroundStyle(.primary)
            Spacer(minLength: 10)
            // The one place the word appears, as in the *Code colours* chooser: the section marks the
            // default nowhere, because a value the reader can always choose back needs no badge.
            if icon == .default {
                Text("Default")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if icon == choice.shown {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 4)
        // One element per row: the drawing is decorative, so a screen reader reads the name and
        // whether it is the one on the Home Screen.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(icon.displayName)
        .accessibilityAddTraits(icon == choice.shown ? [.isButton, .isSelected] : .isButton)
    }

    /// Where the sentence says what happened when the system said no.
    ///
    /// **Ours first, the system's underneath.** The reader needs to know the Home Screen did not
    /// change and what it still shows; the system's words go below as small print, monospaced and
    /// selectable, with their code — the same place every other system error in this app goes.
    @ViewBuilder
    private var footer: some View {
        switch choice {
        case .showing:
            Text("The icon on your Home Screen. Kept on this device.")
        case .refused(let shown, let reason):
            VStack(alignment: .leading, spacing: 6) {
                Text("The icon did not change, so your Home Screen still shows \(shown.displayName). Try again in a moment.")
                Text(reason)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
        }
    }
}

/// One icon, drawn at the size a row needs.
///
/// **The previews are images in the app's own asset catalog**, written by `make icons` from the same
/// artwork as the icons themselves, so a preview cannot drift from what the Home Screen shows. Each has
/// a dark variant, so the row shows the drawing the reader's Home Screen would.
struct AppIconPreviewView: View {

    let icon: AppIcon
    let size: CGFloat

    var body: some View {
        Image(assetName)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var assetName: String {
        switch icon {
        case .granita: "AppIconPreview-Granita"
        case .iceCube: "AppIconPreview-IceCube"
        }
    }
}
