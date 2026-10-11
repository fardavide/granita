# Scoped IPv4 addresses become unscoped HTTPS hosts

On 9 October 2026, the phone running 0.22.0 (173) could read the Mac's health response in Safari,
while Granita could not reconnect locally. Its journal showed Bonjour succeeding in 21–213 ms,
followed by local verification failing in 0–1 ms without any local HTTP request event. The saved
tailnet endpoint then timed out because the Mac's Tailscale connection was stopped.

A diagnostic against the running Mac reproduced the boundary failure. The real Bonjour resolver
returned `192.168.50.185%en0:8737`. Passing that address to the native pinned health probe failed
immediately with `requestNotBuildable("Granita connections require HTTPS")`.

The URL builder already handled scoped IPv6, but handed scoped IPv4 directly to `URLComponents`.
The resulting URL was absent, so the existing invalid-address fallback produced a file URL.
The native transport refused it before logging a request. A regression through the public health
client independently reproduced `file:///v1/health` instead of the expected local HTTPS URL.

Recognize IPv4 with Network's address parser and serialize its four address bytes as dotted decimal
when constructing the URL host. The interface belongs to Network's scoped endpoint, not an IPv4
URL host. Do not remove percent suffixes from arbitrary hostname input. Malformed hostname behavior
and the existing invalid-address fallback remain as before.

IPv6 literals keep their zone and its URL escaping, as required by [0128](0128-an-ipv6-address-is-bracketed-and-its-zone-escaped-and-that.md).
The resolver's address contract, TLS pinning, ATS policy and local/tailnet race are unchanged.

The earlier 15:38 UTC attempts also exhibited a TCP handshake timeout on the LAN. Its underlying
cause was not established. Later successful Bonjour connections and the direct Safari health read
separate that earlier failure from this reproducible URL-construction defect.
