/// Where the finished review goes.
///
/// **A seam rather than one line in a button's action**, which is this repository's own rule for
/// every gesture that reaches the system: a `Ui` view reports what happened, a screen calls a model,
/// and the model calls a protocol its `Domain` owns. The Mac's Settings screen held an `NSPasteboard`
/// call for several releases on the argument that it was "one line with nothing to decide", and what
/// that cost was the question *did pressing Copy put on the pasteboard the string the row actually
/// shows* — which is a real question with a real answer, and one nothing could ask.
///
/// **Fire and forget, and it does not answer.** There is nothing to branch on: `UIPasteboard` cannot
/// refuse, and a `Bool` nobody could produce a `false` for would be a state no screen could ever
/// draw. The decidable half — what the text says — is `ReviewFeedback.document`, which is pure and
/// asserted to the byte.
///
/// **A Copy button rather than a `ShareLink`**, which is design §7's call 1. The destination is a
/// terminal on the Mac the phone is lying beside, and a share sheet puts a system sheet on top of the
/// review sheet to reach an item that would have been the first one anyway. A `ShareLink` can be
/// added later as a second control over this same string with no layout consequence at all.
public protocol ReviewPasteboard: Sendable {

    func copy(_ text: String)
}
