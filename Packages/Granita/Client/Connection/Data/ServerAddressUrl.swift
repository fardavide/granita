import Foundation

import ClientConnectionDomain

extension ServerAddress {

    /// The base URL a session for this Mac is built against, or nothing when the host is not
    /// something a URL can carry.
    ///
    /// **`https` is decided here** rather than in the composition root, because this is the only
    /// layer that knows the Mac serves TLS and the only one with a test that can watch where a
    /// request actually went. Every route the phone reaches — the two before a token and every one
    /// after it — is addressed through this, so a Mac that can be paired with can also be read from.
    ///
    /// **An IPv6 literal needs help that `URLComponents` will not give it**, which is why this is
    /// one function rather than four lines repeated at three call sites. A bare `2001:db8::a1`
    /// assigned to a host reads as a name with a port stuck to it and produces no URL at all, so
    /// every caller fell back to an address nothing answers on and a Mac plainly sitting on the desk
    /// was reported unreachable. `NWPath` makes it worse on the one route that reaches it most: a
    /// link-local address arrives as `fe80::1%en0`, and dropping the zone would not fix the URL and
    /// would name an interface nobody chose.
    ///
    /// RFC 6874 says what the URL wants — the literal inside square brackets, and the zone's `%`
    /// written `%25`. It goes in through `percentEncodedHost` because that is the form: the plain
    /// setter would escape the escape.
    var httpsUrl: URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.port = port
        // A colon cannot appear in a host name, so this asks whether the address is a v6 literal
        // without parsing one.
        if host.contains(":") {
            components.percentEncodedHost = "[\(host.replacingOccurrences(of: "%", with: "%25"))]"
        } else {
            components.host = host
        }
        return components.url
    }
}
