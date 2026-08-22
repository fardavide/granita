import Hummingbird
import Testing

import CoreApiDomain
import ServerApiPresentation

/// The codes are part of the wire contract because the client branches on them, so their statuses
/// are asserted rather than left to whichever `case` was written last.
@Suite("Api error")
struct ApiErrorTests {

    @Test(arguments: ApiErrorCode.allCases)
    func `given any error code when it becomes a response then it is not a server error by accident`(
        code: ApiErrorCode
    ) {
        // given - when
        let status = ApiError(code, message: "because").status

        // then — one of these is the server's own fault and the rest are not. A code that silently
        // became a 500 is a code the phone has no screen for.
        if code == .gitFailure {
            #expect(status == .internalServerError)
        } else {
            #expect(status != .internalServerError)
            #expect(status.code >= 400)
        }
    }

    @Test
    func `given a failure when it is reported then the reason travels with the code`() {
        // given — the reader is three rooms away from the Mac and cannot re-run anything.
        let error = ApiError(.gitFailure, message: "fatal: not a git repository")

        // when - then
        #expect(error.error.message == "fatal: not a git repository")
        #expect(error.error.code == .gitFailure)
    }
}
