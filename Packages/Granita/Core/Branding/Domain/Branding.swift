import Foundation

/// Every string that carries the product's name, in one place, so renaming the product is a
/// change to this file and to `project.yml` and nothing else.
///
/// Nothing here is user-facing copy — that belongs in a string catalogue. These are the
/// identifiers the system matches on: a Bonjour service type the client browses for, a URL scheme
/// the pairing QR encodes, and the directory the Mac app owns on disk.
public enum Branding {

    /// The product name, as shown in the menu bar, the Bonjour service instance and `/v1/health`.
    public static let productName = "Granita"

    /// Reverse-DNS prefix both bundle identifiers are built from.
    public static let bundleIdentifierPrefix = "dev.fardavide.granita"

    /// The Bonjour service type the Mac advertises and the phone browses for.
    ///
    /// Registered with the leading underscore and the `_tcp` suffix that DNS-SD requires; the
    /// label is capped at fifteen characters, which `granita` is comfortably inside.
    public static let bonjourServiceType = "_granita._tcp"

    /// Scheme of the pairing URL a QR code encodes: `granita://pair?host=&port=&code=&spki=`.
    public static let urlScheme = "granita"

    /// Name of the directory the Mac app owns inside Application Support.
    public static let applicationSupportDirectoryName = "Granita"

    /// The API contract version. The Mac app and the TestFlight phone app ship independently, so
    /// skew is guaranteed: the client refuses to pair on a mismatch rather than decoding a
    /// payload it half-understands.
    public static let apiVersion = 1

    /// Default TCP port. Taken ports fall back automatically and the chosen one is persisted.
    public static let defaultPort = 8737

    /// The build's marketing version, reported by `/v1/health` so a phone can say "update your Mac
    /// app" rather than failing to decode a payload it half-understands.
    ///
    /// Read from the bundle when there is one — the menu bar app — and falling back to a literal
    /// for `swift run`, which has no bundle to read. The literal is the one place this repeats
    /// `MARKETING_VERSION` in project.yml, and the test below pins them together.
    public static var serverVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? fallbackServerVersion
    }

    static let fallbackServerVersion = "0.0.4"
}
