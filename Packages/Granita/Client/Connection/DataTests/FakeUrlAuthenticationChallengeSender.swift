import Foundation
import Testing

final class FakeUrlAuthenticationChallengeSender: NSObject, URLAuthenticationChallengeSender, Sendable {

    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {
        Issue.record("The session delegate should answer through its completion handler")
    }

    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {
        Issue.record("The session delegate should answer through its completion handler")
    }

    func cancel(_ challenge: URLAuthenticationChallenge) {
        Issue.record("The session delegate should answer through its completion handler")
    }
}
