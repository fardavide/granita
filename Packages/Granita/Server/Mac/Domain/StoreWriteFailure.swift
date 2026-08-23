/// Why something a Settings tab was asked to do did not happen.
///
/// Two fields rather than one string, because this product's failure idiom is our sentence with the
/// system's demoted to small print — the same shape General's refused login item and the phone's
/// discovery failure already use. A store that refuses says `No space left on device`, which is true
/// and is not a sentence anybody wrote for a reader.
///
/// Shared by Projects and Devices rather than named for either. Both tabs write to the same
/// document, and a switch that springs back and a Revoke that leaves the row where it was are the
/// same defect: a control that did nothing and said nothing.
public struct StoreWriteFailure: Hashable, Sendable {

    /// Ours, and always present.
    public let sentence: String

    /// The system's, when there is one. Absent where the refusal was ours to word in the first
    /// place, because repeating our own sentence in small print underneath it says nothing twice.
    public let reason: String?

    public init(sentence: String, reason: String?) {
        self.sentence = sentence
        self.reason = reason
    }
}
