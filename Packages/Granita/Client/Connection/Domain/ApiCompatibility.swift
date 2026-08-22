import CoreApiDomain
import CoreBrandingDomain

/// Whether this phone and that Mac speak the same contract, and which of them is behind.
///
/// Read from `/v1/health`, which is the one route that answers before pairing — so the mismatch is
/// caught before a reader has spent a code, rather than as a route that half-decodes afterwards.
/// The two apps ship through different pipelines, so skew is guaranteed rather than possible.
public enum ApiCompatibility: Hashable, Sendable {

    case sameContract

    /// That Mac serves an older contract than this phone speaks. Its app has to be updated, and
    /// nothing on the phone can work around it.
    case macIsBehind(serving: Int)

    /// That Mac serves a newer contract. This is the phone that is behind — a TestFlight build that
    /// was not installed, most likely.
    case phoneIsBehind(serving: Int)
}

extension HealthResponse {

    /// Which of the two ends is out of date, if either.
    ///
    /// A property on the payload rather than a free function, because there is exactly one number
    /// to compare it against and passing it in every time would only make it possible to pass the
    /// wrong one.
    public var compatibility: ApiCompatibility {
        if apiVersion == Branding.apiVersion {
            .sameContract
        } else if apiVersion < Branding.apiVersion {
            .macIsBehind(serving: apiVersion)
        } else {
            .phoneIsBehind(serving: apiVersion)
        }
    }
}
