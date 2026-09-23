import Foundation

/// The system text size the reader has chosen, as far as the code's own size is concerned.
///
/// **A domain spelling of `DynamicTypeSize`**, for the reason `HighlightAppearance` is not
/// `ColorScheme`: *Follow system* is arithmetic over these twelve steps, and a rule that can only be
/// stated in a view layer cannot be tested without one. The view maps SwiftUI's enum onto this;
/// nothing here knows there is one.
///
/// **The raw value is the distance from Large**, which is the only question anything asks of this
/// type — Large is where every measurement in design §4 was taken, so it is the origin rather than
/// the fourth case.
public enum ReaderTextSize: Int, Hashable, Sendable, CaseIterable {

    case xSmall = -3
    case small = -2
    case medium = -1
    case large = 0
    case xLarge = 1
    case xxLarge = 2
    case xxxLarge = 3
    case accessibility1 = 4
    case accessibility2 = 5
    case accessibility3 = 6
    case accessibility4 = 7
    case accessibility5 = 8

    /// What a phone that has never been asked answers, and the size the design's numbers assume.
    public static let `default` = ReaderTextSize.large

    /// How far this is from Large. Named rather than left as `rawValue`, because an integer with no
    /// name at a call site doing arithmetic on point sizes says nothing about what it counts.
    public var stepsFromLarge: Int { rawValue }
}

/// How big the code is drawn in one of the diff's two modes.
///
/// **Two states rather than an optional point size.** `nil` meaning *follow the system* is the
/// invented nullability this project refuses: the two are different answers to the same question,
/// and the segmented control the reader sees has exactly these two segments.
public enum CodeSizeChoice: Hashable, Sendable {

    case followSystem
    case custom(CGFloat)
}

/// The diff's code size, in the two halves issue #106 splits it into.
///
/// **Two settings, not one, and that is design call 10 rather than a convenience.** Unified is a
/// question about **legibility** — how small the reader will go, with about 49 characters either way
/// — and split is a question about **width**, where every point costs about two characters a side
/// from a number that starts at 22. One setting makes the reader pay for one in the other. A
/// "smaller in split" offset was rejected with it: a third number to hold in your head, and wrong the
/// moment a reader wants split *larger*, which on a Mac is the likely case.
///
/// **Only one of the two is ever on screen at a time**, because the split mode governs the whole
/// scroll rather than the block rows alone — context drawn at one size beside a block drawn at
/// another is two text sizes in one file.
public struct CodeSize: Hashable, Sendable {

    /// The range the stepper offers, and the range `systemPointSize` clamps into.
    ///
    /// Eight because below it SF Mono stops being code and starts being a texture; seventeen because
    /// it is where the iPad's pane still holds a usable split and the phone's unified scroll is down
    /// to about 32 characters.
    public static let smallest: CGFloat = 8
    public static let largest: CGFloat = 17

    /// Both halves following the system, which is what every reader has been reading in: at Large it
    /// is today's 11pt, and 12 beside the selector.
    public static let `default` = CodeSize(unified: .followSystem, split: .followSystem)

    public let unified: CodeSizeChoice
    public let split: CodeSizeChoice

    public init(unified: CodeSizeChoice, split: CodeSizeChoice) {
        self.unified = unified
        self.split = split
    }

    /// What *Follow system* gives at a text size, which is one point per Dynamic Type step.
    ///
    /// **This is a deliberate reversal**: `DiffLineHeight` has said since it existed that the code
    /// does *not* scale with Dynamic Type, which left a reader who had made every other word on the
    /// phone larger reading eleven-point code. Large lands on exactly what shipped before this
    /// setting existed, so nobody's screen moves on the update.
    public static func systemPointSize(at textSize: ReaderTextSize, besideSelector: Bool) -> CGFloat {
        let base = besideSelector ? DiffPaneLayout.codePointSizeBesideTheSelector : DiffPaneLayout.codePointSize
        return min(largest, max(smallest, base + CGFloat(textSize.stepsFromLarge)))
    }

    /// The unified scroll's size, which nothing ever argues with.
    public func resolvedUnified(at textSize: ReaderTextSize, besideSelector: Bool) -> CodeSizeResolution {
        .asChosen(Self.pointSize(of: unified, at: textSize, besideSelector: besideSelector))
    }

    /// A split block's size, held back where *Follow system* would cross the floor.
    ///
    /// **Davide's call, 23 September 2026.** Twelve points is exactly twenty characters a side at
    /// 390pt, so every Dynamic Type size above Large would otherwise leave a *Follow system* reader
    /// with no columns at all. The floor does not bend and an accessibility text size never takes the
    /// feature away; the group says which of the two happened.
    ///
    /// **The ceiling is this width's rather than a constant twelve**, which is what keeps a reader on
    /// an iPad or a wide Mac window from being handed the phone's answer — there, seventeen points
    /// still leaves thirty-five characters a side.
    ///
    /// **A custom size is never held back.** Capping the stepper was rejected as a ceiling that moves
    /// while a Mac window is dragged; the reader gets the number they set, and the toolbar item says
    /// what it costs.
    public func resolvedSplit(
        at textSize: ReaderTextSize,
        besideSelector: Bool,
        inRowWidth rowWidth: CGFloat
    ) -> CodeSizeResolution {
        let asked = Self.pointSize(of: split, at: textSize, besideSelector: besideSelector)
        guard case .followSystem = split else { return .asChosen(asked) }
        // Nothing to hold back to is not the same as nothing to hold back: below the floor at every
        // size in the range, clamping would only pick a smaller size that also refuses.
        guard
            let ceiling = SplitBlockLayout.largestFittingPointSize(
                inRowWidth: rowWidth,
                trailingInset: DiffGutter.codeTrailingInset
            ),
            asked > ceiling
        else {
            return .asChosen(asked)
        }
        return .heldBack(to: ceiling, from: asked)
    }

    private static func pointSize(
        of choice: CodeSizeChoice,
        at textSize: ReaderTextSize,
        besideSelector: Bool
    ) -> CGFloat {
        switch choice {
        case .followSystem:
            systemPointSize(at: textSize, besideSelector: besideSelector)
        // Clamped here rather than on the way out of storage, so one funnel answers for a
        // hand-edited defaults file and for a backup restored from a build with a wider range.
        case .custom(let points):
            min(largest, max(smallest, points))
        }
    }
}

/// The size the code is drawn at, and whether the reader's own answer survived to it.
///
/// **A closed pair rather than a size and a flag**, because the second case carries the number that
/// was asked for — and that number is the whole of what the split group has to say when it holds one
/// back.
public enum CodeSizeResolution: Hashable, Sendable {

    /// The reader's own number, or their text size's, used as it stands.
    case asChosen(CGFloat)

    /// *Follow system* asked for more than two columns can take at this width.
    case heldBack(to: CGFloat, from: CGFloat)

    /// What the code is actually drawn at.
    public var pointSize: CGFloat {
        switch self {
        case .asChosen(let points): points
        case .heldBack(let points, _): points
        }
    }

    /// What was asked for before the ceiling was applied, and nothing where nothing was.
    ///
    /// The absence is real rather than invented: in `asChosen` there is no second number, and a
    /// caller that received the same value twice would have to compare them to find that out.
    public var heldBackFrom: CGFloat? {
        switch self {
        case .asChosen: nil
        case .heldBack(_, let asked): asked
        }
    }
}

/// Why two columns are not available, when they are not.
///
/// **The cause decides the sentence, because only one of the two is something the reader can act on
/// from where they are.** A phone cannot be widened, so *Widen the window* on one is advice with no
/// gesture behind it — which is a control that is disabled and does not really say why. Davide's
/// call, 23 September 2026; one sentence naming both levers was rejected for the same reason.
public enum SplitRefusal: Hashable, Sendable {

    /// The room ran out. A Mac window dragged under the floor, and the case design §4.2 drew.
    case tooNarrow

    /// The size ran out. A code size large enough that even this width cannot hold two columns of
    /// it — the state the code-size setting made reachable on a phone for the first time.
    case codeTooLarge

    /// Which of the two, or nothing at all where a block fits.
    ///
    /// **The width is asked first and the size second**, because a row too narrow to hold a split at
    /// the smallest size this setting reaches cannot be fixed by choosing one.
    ///
    /// **A width nobody has measured yet refuses nothing.** A first render reports its geometry after
    /// the body it laid out, so a zero treated as a narrow window would disable the toolbar item for
    /// one frame every time this screen appeared — a control that blinks off and on says the wrong
    /// thing twice.
    public static func refusal(
        inRowWidth rowWidth: CGFloat,
        atPointSize pointSize: CGFloat,
        trailingInset: CGFloat
    ) -> SplitRefusal? {
        guard rowWidth > 0 else { return nil }
        let fits = { (points: CGFloat) in
            SplitBlockLayout.fits(
                rowWidth: rowWidth,
                highestLineNumber: SplitBlockLayout.statedHighestLineNumber,
                atPointSize: points,
                trailingInset: trailingInset
            )
        }
        if fits(pointSize) {
            return nil
        }
        return fits(CodeSize.smallest) ? .codeTooLarge : .tooNarrow
    }

    /// What the disabled toolbar item carries, which is the reason it owes the reader.
    public var sentence: String {
        switch self {
        case .tooNarrow: "Widen the window to review side by side"
        case .codeTooLarge: "Choose a smaller code size to review side by side"
        }
    }
}
