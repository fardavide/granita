# Remote IP pinning needs a scoped ATS manual-trust exception

On 12 September 2026 Davide supplied a 0.11.1 (137) phone report showing a matched SPKI pin
followed by `NSURLErrorDomain (-1200)`. He approved a controlled policy comparison and a scoped
fix only if that comparison confirmed the cause.

A real URLSession handshake inside the iOS app host reproduced that sequence against a disposable
ten-year P-256 fixture. A local HTTP CONNECT tunnel changes only the socket destination, leaving
the requested `100.81.42.98` URL and native TLS evaluation intact. With the app's existing ATS
dictionary, the matching pin was accepted and HTTPS failed with `-1200`. Adding only a
`100.64.0.0/10` exception made the unchanged request return HTTP 200 and the fixture response.
This comparison ran on iOS 26.5; Davide's iOS 27 phone still needs post-release confirmation.

The phone declares `NSExceptionAllowsInsecureHTTPLoads` only for that IPv4 CIDR, allowing our
existing manual certificate evaluation without lowering TLS minimums or forward-secrecy
requirements. No global arbitrary-load exception, certificate replacement or server update is
needed for this reproduced failure. The native key also permits HTTP within its range, so the
client independently enforces HTTPS rather than treating the plist as that guarantee. The
transport refuses non-HTTPS URLs before dispatch, and both trust delegates decline redirects
because Granita's API has no redirect routes. These safeguards were driven by failing tests.

Apple documents that manual trust cannot loosen ATS-protected connections and that current OS
versions support IP/CIDR exceptions:
[manual server trust](https://developer.apple.com/documentation/foundation/performing-manual-server-trust-authentication),
[exception domains](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsexceptiondomains),
[manual-trust exception](https://developer.apple.com/documentation/bundleresources/information-property-list/nsexceptionallowsinsecurehttploads).

The initial LAN-IP control received a different certificate, despite the fixture's CONNECT
upstream being loopback-only. That result is not evidence about fixture TLS or LAN policy; it
indicates the proxy path must be witnessed before that control can be trusted. It did not change
the valid before/after tailnet result. Acceptance fixtures contain only a public disposable test
identity, never the Mac's certificate or private key.

Final fixture controls require a witnessed CONNECT tunnel: the correct pin returns the fixture
body over HTTPS, a wrong pin is refused, and the same certificate remains blocked outside the
tailnet range. The certificate SAN includes both compared IPs, so the outside-range refusal is
not explained by a differing hostname. The test-only scheme is non-archivable and runs in the
existing iOS snapshot CI job. All 1,364 package tests and all six coverage values pass against
main at `232e0ef`; unsigned app/package builds pass too.

During final preparation, `make resolve` twice failed its existing full-graph validation: Xcode
wrote 30 pins to the workspace lockfile, while the committed package lockfile retained only 26.
The sanctioned target now copies its freshly resolved workspace graph back before validating it.
The lockfile is regenerated through that target, including its normal transitive-version refresh;
no external dependency was added. Separate pre-existing local-runner Makefile changes are preserved
unstaged and are not part of this TLS correction.

The workspace lock survives XcodeGen regeneration and initially made `make verify-generated`
report an untracked cache as source drift. Only that exact runtime cache file is now ignored;
the canonical package lock and all generated project/fixture sources remain checked. The
sanctioned generated-source verifier passes with no project or golden-fixture drift.

