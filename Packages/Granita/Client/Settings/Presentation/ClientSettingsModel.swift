import Observation

import ClientConnectionDomain
import ClientSettingsDomain
import CoreReviewDomain

/// What the reader has decided about the shape of every review they export, and where those
/// decisions currently are.
///
/// **The Mac wins at read time and the phone wins at write time.** Opening this screen asks the Mac
/// what it holds; changing something on it takes effect here immediately and is sent when the Mac
/// will have it. The alternative — discarding what a reader typed on a screen that accepted it — is
/// the one outcome this whole shape exists to prevent.
@MainActor
@Observable
public final class ClientSettingsModel {

    private let repository: any GranitaRepository

    /// Whether this phone has a Mac at all. Held rather than inferred from a failure, because
    /// "nobody to ask" and "asked and it did not answer" are different screens.
    private let isPaired: Bool

    public private(set) var settings: ReviewSettings = .unset
    public private(set) var standing: ReviewSettingsStanding

    /// The field's text, which is this phone's answer from the moment it is typed.
    ///
    /// **Separate from `settings` on purpose.** A text field's value is not written anywhere until
    /// editing ends, and that gap is the one thing on this screen a reader can lose — so the field
    /// is bound here and committed on a pause, before anything is sent anywhere.
    public var openingLineDraft: String = ReviewSettings.defaultOpeningLine

    public let macName: String

    public init(macName: String, isPaired: Bool, repository: any GranitaRepository) {
        self.macName = macName
        self.isPaired = isPaired
        self.repository = repository
        standing = isPaired ? .settled : .noMac
    }

    /// Whether the reader has ever chosen an opening line.
    ///
    /// **Half of how the default is told apart**, the other half being the sentence underneath. It
    /// is never told by greying the field: a placeholder says *type something here* and these words
    /// are the exact string that will be exported.
    public var isOpeningLineDefault: Bool { settings.openingLine == nil }

    public func load() async {
        guard isPaired else { return }
        do {
            settings = try await repository.reviewSettings()
            openingLineDraft = settings.openingLine ?? ReviewSettings.defaultOpeningLine
            standing = .settled
        } catch .routeNotServed {
            standing = .tooOld
        } catch {
            // Unreachable rather than refused: nothing was rejected, so what this phone holds stands
            // and the reader may still change it.
            standing = .queued
        }
    }

    /// Takes the field's text as this phone's answer and offers it to the Mac.
    ///
    /// Called when editing ends rather than per keystroke: 29 characters would be 29 requests over a
    /// LAN, and the Mac's store already coalesces its own writes at one second.
    public func commitOpeningLine() async {
        // Cleared to nothing is a real answer — a review that begins at its first comment — and it
        // is not the same as never having chosen, which is what Reset restores.
        await send(ReviewSettingsPatch(openingLine: .some(openingLineDraft), identifier: nil))
    }

    public func choose(_ identifier: ReviewIdentifier) async {
        await send(ReviewSettingsPatch(openingLine: nil, identifier: identifier))
    }

    /// Puts the opening line back to the built-in one, which is the only thing that does.
    public func resetOpeningLine() async {
        openingLineDraft = ReviewSettings.defaultOpeningLine
        await send(ReviewSettingsPatch(openingLine: .some(nil), identifier: nil))
    }

    // MARK: -

    /// Applies a change here first, then offers it to the Mac.
    ///
    /// **Only the fields the reader named travel.** A patch made on a phone that has never read this
    /// Mac's values cannot overwrite the setting it did not touch, which is what makes editing while
    /// the Mac is away safe rather than merely possible.
    private func send(_ patch: ReviewSettingsPatch) async {
        settings = ReviewSettings(
            openingLine: patch.openingLine ?? settings.openingLine,
            identifier: patch.identifier ?? settings.identifier
        )
        guard standing.acceptsEdits else { return }

        standing = .saving
        do {
            settings = try await repository.updateReviewSettings(patch)
            standing = .settled
        } catch .routeNotServed {
            standing = .tooOld
        } catch .unreachable, .cancelled, .requestNotBuildable {
            // Kept here and sent when it answers. Nothing is lost and nothing is undone on screen —
            // the receipt below the controls already shows the value this phone will use.
            standing = .queued
        } catch {
            standing = .refused(reason: error.diagnostic)
        }
    }
}
