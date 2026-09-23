import SwiftUI

import ClientViewerDomain

/// The app under the appearance it was told to draw in.
///
/// **It exists so that the two things a forced appearance has to reach are reached from inside a
/// `body`.** Observation only tracks a read that happens while a view's body is being evaluated, so a
/// composition root that read the model straight inside `WindowGroup`'s closure would apply the right
/// appearance at launch and never hear about a change — a picker that looked operable and did nothing
/// the second time. This view's body does the reading, so a tap on the segment redraws the app.
///
/// **`preferredColorScheme` belongs here rather than on the sheet**, and that is not a tidiness
/// argument: a sheet is its own presentation, so forcing Light on it would leave the diff behind it
/// dark. At the root it covers everything, and `PairingScannerView`'s own `.dark` survives underneath
/// it because the innermost non-nil value wins — which is what keeps a viewfinder dark under a forced
/// Light.
///
/// **The theme is handed to the caller rather than put in the environment here**, because the key it
/// goes under belongs to the feature that reads it and this target cannot see that feature's views.
/// One modifier in the composition root is the whole of the join.
public struct AppearanceRoot<Content: View>: View {

    /// Pinned for the reason every screen here pins its model: a scene's body is re-evaluated, and a
    /// plain property would build a second model — reading the defaults again and losing nothing, but
    /// also replacing the object the rest of the app is observing.
    @State private var model: AppearanceModel

    /// **Three plain values rather than one type, because the keys they go under belong to the
    /// feature that reads them and this target cannot see that feature's views.** That is the same
    /// argument the theme already carried; the split mode arrives with its setter beside it because
    /// the control that reads it is the control that writes it.
    private let content: (CodeTheme, Bool, @escaping (Bool) -> Void) -> Content

    public init(
        model: AppearanceModel,
        @ViewBuilder content: @escaping (CodeTheme, Bool, @escaping (Bool) -> Void) -> Content
    ) {
        _model = State(initialValue: model)
        self.content = content
    }

    public var body: some View {
        // Read inside `body` so observation sees them: a value read outside would be right at launch
        // and deaf to every change after it, which is a control that works once.
        content(model.codeTheme, model.isSideBySide) { [model] isOn in
            model.chooseSideBySide(isOn)
        }
        .preferredColorScheme(model.colorScheme)
    }
}
