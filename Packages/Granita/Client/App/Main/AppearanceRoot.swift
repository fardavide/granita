import SwiftUI

import ClientSettingsPresentation
import ClientViewerDomain

/// The app under the appearance it was told to draw in, and the one view that is the whole window.
///
/// **It exists so that the things a forced appearance has to reach are reached from inside a
/// `body`.** Observation only tracks a read that happens while a view's body is being evaluated, so a
/// scene that read the model straight inside `WindowGroup`'s closure would apply the right appearance
/// at launch and never hear about a change — a picker that looked operable and did nothing the second
/// time. This view's body does the reading, so a tap on the segment redraws the app.
///
/// **`preferredColorScheme` belongs here rather than on the sheet**, and that is not a tidiness
/// argument: a sheet is its own presentation, so forcing Light on it would leave the diff behind it
/// dark. At the root it covers everything, and `PairingScannerView`'s own `.dark` survives underneath
/// it because the innermost non-nil value wins — which is what keeps a viewfinder dark under a forced
/// Light.
///
/// **It also reports this device's reading context, because it is the only view that is the window.**
/// The *Code size* screen states what a point size buys in characters, which is arithmetic over the
/// width the diff is read at — and that screen is a sheet, so it cannot see the pane it is
/// describing. Measuring here and taking the tree's width off gives one answer both screens can use.
/// `WorktreeDiffScreen` still measures its own pane for the decision that matters, which is whether
/// its toolbar item is operable.
///
/// **It is in `Main` and not in a feature's `Presentation`, which is a correction rather than a
/// convenience.** It was filed under `ClientSettingsPresentation` until 0.19.0, where it matched the
/// shape the composition-root exemption was written for and the exemption missed it: a view a host
/// test cannot construct and a baseline cannot honestly photograph — the snapshot harness injects
/// the interface style as a trait, so a render of this view comes back in the harness's appearance
/// whatever it prefers. Everything it decides lives in a judged module: the row-width arithmetic in
/// `DiffPaneLayout`, the text-size mapping beside `AppearanceModel`. What is left here is a window
/// measurement and one call, which is what a root is for. In `.ai/docs/decisions.md`.
struct AppearanceRoot<Content: View>: View {

    /// Pinned for the reason every screen here pins its model: a scene's body is re-evaluated, and a
    /// plain property would build a second model — reading the defaults again and losing nothing, but
    /// also replacing the object the rest of the app is observing.
    @State private var model: AppearanceModel

    /// The last width this window reported, kept so a text size changed while the window stood still
    /// still has a width to be re-derived against.
    @State private var windowWidth: CGFloat = 0

    /// **Four plain values rather than the model**, so the scene puts each one under the environment
    /// key its own feature owns rather than handing an object down. The split mode arrives with its
    /// setter beside it because the control that reads it is the control that writes it; the other
    /// three are read-only, being set two navigations away on a sheet.
    private let content: (CodeTheme, CodeSize, ReaderTextSize, Bool, @escaping (Bool) -> Void) -> Content

    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    /// What *Follow system* follows. The mapping onto SwiftUI's enum lives beside `AppearanceModel`,
    /// where a test calls it — the diff and the settings sheet are siblings over `Domain` and cannot
    /// share a `Ui`, so this root is where the one answer is read and handed to both.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        model: AppearanceModel,
        @ViewBuilder content: @escaping (CodeTheme, CodeSize, ReaderTextSize, Bool, @escaping (Bool) -> Void) -> Content
    ) {
        _model = State(initialValue: model)
        self.content = content
    }

    var body: some View {
        // Read inside `body` so observation sees them: a value read outside would be right at launch
        // and deaf to every change after it, which is a control that works once.
        content(model.codeTheme, model.codeSize, model.textSize, model.isSideBySide) { [model] isOn in
            model.chooseSideBySide(isOn)
        }
        .preferredColorScheme(model.colorScheme)
        // Watched rather than read once, because all three change under a reader who pressed nothing:
        // an iPad is rotated, a Mac window is dragged, and a text size is changed in Settings and
        // returned from.
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            windowWidth = width
            note()
        }
        .onChange(of: dynamicTypeSize) { _, _ in
            note()
        }
    }

    // MARK: -

    private func note() {
        model.note(
            windowWidth: windowWidth,
            fitsSelectorColumn: fitsSelectorColumn,
            textSize: ReaderTextSize(dynamicTypeSize)
        )
    }

    /// Whether a 320pt column could stand beside the code here, which is what decides whether
    /// *Follow system* is based on eleven points or twelve.
    ///
    /// The horizontal size class rather than the device, because an iPad in a narrow multitasking
    /// width is the phone's layout too — the same rule `WorktreeDiffScreen` applies to the same
    /// question.
    private var fitsSelectorColumn: Bool {
        #if os(macOS)
        true
        #else
        horizontalSizeClass == .regular
        #endif
    }
}
