import Hummingbird

import CoreDiagnosticsDomain

/// Says what was asked of this Mac and what it answered.
///
/// The second half of what design §7's footnote promises the verbose switch turns on: *every request
/// and every git invocation*. It sits on the router itself rather than on the authenticated group,
/// because the requests worth reading about are disproportionately the ones that never got that far
/// — a phone that cannot pair is asking `/v1/pair` and being refused, and a group's middleware would
/// be silent about exactly that.
///
/// **Not a second connection log.** That panel is fifty coalesced attempts with the reason each was
/// turned away, built to be read on screen under pressure; this is a line per request in the system
/// log, and it exists so the *order* of a hundred of them can be read after the fact. Two readers,
/// two lifetimes.
struct DiagnosticsMiddleware<Context: RequestContext>: RouterMiddleware {

    let diagnostics: any Diagnostics

    func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        // Method and path, never the query and never a body. `/v1/pair` carries a live pairing code
        // in its body and `?projectID=` carries an identifier that resolves to a folder on this Mac:
        // a log has a different lifetime and different readers than either.
        let asked = "\(request.method) \(request.uri.path)"
        diagnostics.detail(asked, about: .requests)
        do {
            let response = try await next(request, context)
            diagnostics.detail("\(asked) → \(response.status.code)", about: .requests)
            return response
        } catch {
            // A note rather than detail, and the same reason the git decorator gives: a request that
            // threw is why somebody is reading this, and it must not be behind a switch they had to
            // think of turning on first. Rethrown, so the framework still writes the real response.
            diagnostics.note("\(asked) failed: \(error)", about: .requests)
            throw error
        }
    }
}
