import SwiftUI

/// The type sizes of an empty state's title and description, stated rather than left to the system.
///
/// **iOS 27 inverted `ContentUnavailableView`'s hierarchy**: it sets the title at headline size over
/// a title3 description, so every empty state read as a caption over its own body text. These pin
/// what iOS 26 drew — a title2 title over body text — and are applied to the title and the
/// description separately, because a font on the view itself reaches both.
///
/// **One copy per `Ui` module**, because a `Ui` module may depend on nothing but `Domain` and
/// SwiftUI, so no module can hold it for all of them. Keep the copies identical.
extension View {

    func emptyStateTitle() -> some View {
        font(.title2.bold())
    }

    func emptyStateDescription() -> some View {
        font(.body)
    }
}
