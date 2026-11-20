import SwiftUI

import ClientSettingsDomain

/// Choose the usual app icon and whether the Home Screen follows the holiday calendar.
///
/// **The same shape as the *Code colours* chooser, on purpose** — a stock grouped list with a
/// checkmark, pushed onto the sheet's own stack, each row the thing itself rather than its name. The
/// section's rule applies here too: the reader is choosing a drawing, so every surface shows the
/// drawing.
///
/// **No Apply and no confirmation of our own.** iOS confirms a changed icon with an alert of its own,
/// which is the one feedback this needs; a second one from us would be the same sentence twice.
public struct AppIconChooserView: View {

    private let choice: AppIconChoice
    private let selection: AppIcon
    private let schedule: AppIconSchedule
    private let onChoose: (AppIcon) -> Void
    private let onChooseSchedule: (AppIconSchedule) -> Void

    public init(
        choice: AppIconChoice,
        selection: AppIcon,
        schedule: AppIconSchedule,
        onChoose: @escaping (AppIcon) -> Void,
        onChooseSchedule: @escaping (AppIconSchedule) -> Void
    ) {
        self.choice = choice
        self.selection = selection
        self.schedule = schedule
        self.onChoose = onChoose
        self.onChooseSchedule = onChooseSchedule
    }

    public var body: some View {
        Form {
            Section {
                Toggle("Seasonal icons", isOn: Binding(
                    get: { schedule == .automatic },
                    set: { onChooseSchedule($0 ? .automatic : .manual) }
                ))
            } footer: {
                footer
            }
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
            }
        }
        .animation(.default, value: choice.shown != selection)
        .animation(.default, value: choice)
        .navigationTitle("App icon")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: -

    @ViewBuilder
    private func row(for icon: AppIcon) -> some View {
        HStack(spacing: 14) {
            AppIconPreviewView(icon: icon, size: 48)
            Text(icon.displayName)
                .foregroundStyle(.primary)
            Spacer(minLength: 10)
            if icon == selection {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 4)
        // VoiceOver reads each icon's name and whether it is the saved choice.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(icon.displayName)
        .accessibilityAddTraits(icon == selection ? [.isButton, .isSelected] : .isButton)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Uses holiday icons during the season, then restores your chosen icon.")
            switch choice {
            case .showing(let shown):
                if shown != selection {
                    Text("Now showing \(shown.displayName).")
                        .foregroundStyle(Color.primary)
                }
            case .refused(let shown, let reason):
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
        case .christmas: "AppIconPreview-Christmas"
        }
    }
}
