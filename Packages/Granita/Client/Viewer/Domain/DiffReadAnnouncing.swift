/// Says out loud the one thing on the diff screen a reader could not have caused.
///
/// **A file arriving announces nothing**, and that is the decision this protocol exists to make
/// visible rather than a gap in it: five files land at once and the reader asked for no particular
/// one, so five interruptions would be the app describing its own plumbing in the one modality where
/// it cannot be scrolled past. A refused batch is the opposite — it is news, and the control that
/// answers it is chrome at the far end of the screen, which a reader who cannot see it has no way to
/// discover.
public protocol DiffReadAnnouncing: Sendable {

    @MainActor func announce(_ failure: DiffBatchFailure)
}
