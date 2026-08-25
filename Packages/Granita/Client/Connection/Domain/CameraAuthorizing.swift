/// Whether this app may open the camera, and the one chance it gets to ask.
///
/// AVFoundation is not named above `Data`, and there is nothing to lose by that: what a screen needs
/// from the camera is which of design §5's states to draw, which is four answers rather than a
/// framework.
public protocol CameraAuthorizing: Sendable {

    /// What the system already knows, without asking anybody anything.
    ///
    /// Read on the way in, because it is what decides whether the alert is raised at all — and
    /// because three of its four answers are screens rather than a wait.
    var current: CameraAccess { get }

    /// Raises the system alert and answers with what it left behind.
    ///
    /// **iOS gives an app one of these, ever.** So it is asked from the screen the alert lands on
    /// rather than ahead of it: design §5 rejects pre-flighting on the entry screen precisely
    /// because that burns the one prompt at the moment it is least explicable. Asking again after an
    /// answer returns the standing one and shows nothing.
    func request() async -> CameraAccess
}

// MARK: -

/// What the camera is to this app right now.
///
/// **Four cases for design §5's three drawn screens**, and the fourth is the whole reason this is an
/// enumeration rather than a `Bool`. The refusal screen carries *Turn the Camera On in Settings* — a
/// plain button under the six-word primary, there so a reader who declined by reflex can change
/// their mind in one tap. Under a restriction there is no switch behind it, and the same screen
/// would then be shipping a control that does nothing, which is the defect this project is named
/// for. Absent is a legitimate state, and it is the one *Open TestFlight* already settled next door.
public enum CameraAccess: Hashable, Sendable {

    /// Nobody has answered yet, and the alert is about to be over whatever is drawn. Design §5's
    /// first camera state, and the one usually left undrawn: it holds a viewfinder symbol, one line,
    /// and — already — the way past it, because whichever way the reader answers, the answer was
    /// behind the alert.
    case notAsked

    /// The viewfinder may open.
    case granted

    /// The reader said no. Nothing has gone wrong and the screen does not pretend otherwise: the six
    /// words are the primary action and Settings is not mentioned in the description at all.
    case refused

    /// Something that is not the reader is holding the camera shut — a device policy, or Screen
    /// Time. The same screen as a refusal, minus the one control that cannot work.
    case restricted
}
