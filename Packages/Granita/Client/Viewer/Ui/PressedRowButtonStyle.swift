import SwiftUI

/// A list row that says it was pressed.
///
/// **It exists because `.plain` inside a `List` draws nothing at all.** The system's own row
/// highlight comes with the automatic style, which also tints the whole label with the accent
/// colour — and a filename in blue is a link rather than a file. Every row in §3's selector is a
/// jump whose effect happens somewhere else on screen, so the press is the only feedback that
/// belongs to the row itself.
///
/// The fill is drawn behind the label rather than by dimming it: a row that fades under the thumb
/// reads as a row going away, which is the opposite of what a jump is about to do.
struct PressedRowButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // Edge to edge, which is why the row's insets live inside its label rather than on the
            // list — a highlight that stops short at both ends reads as a chip in a list rather than
            // as the list's own row.
            .background(configuration.isPressed ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
    }
}

extension ButtonStyle where Self == PressedRowButtonStyle {

    static var pressedRow: PressedRowButtonStyle { PressedRowButtonStyle() }
}
