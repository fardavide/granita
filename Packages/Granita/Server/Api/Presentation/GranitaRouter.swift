import Hummingbird

/// Builds the HTTP surface.
///
/// Routes live here rather than in the composition root so they can be exercised in-process by the
/// test client — no port bound, no TLS identity, no Bonjour — while the composition root keeps the
/// job of deciding what implementations they run against.
public enum GranitaRouter {

    public static func build(serverVersion: String) -> Router<BasicRequestContext> {
        let router = Router()

        // Unauthenticated, deliberately, along with pairing: a phone that cannot yet prove who it
        // is still has to be able to find out whether it is talking to a Granita of a version it
        // understands.
        router.get("/v1/health") { _, _ in
            HealthResponse(serverVersion: serverVersion)
        }

        return router
    }
}

extension HealthResponse: ResponseEncodable {}
