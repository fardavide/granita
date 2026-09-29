# The identity's handle is its common name, because the Keychain discards the one we choose

Two Keychain behaviours cost a fingerprint that changed on every launch, which is every paired
device silently locked out — the key is what they pin.

**A certificate's label is derived from its subject common name.** `SecItemAdd` accepts a
`kSecAttrLabel` for a certificate and throws it away; the file-based keychain writes the common name
instead. Searching back for the label we chose therefore found nothing, and each run generated a new
identity, stored it, and served it.

**A `kSecClassIdentity` search does not filter on the key attributes it documents.** The obvious
repair — tag the private key and search identities by that tag — returned Davide's *Apple
Development* identity on the first try, whose RSA key then failed to read as P-256 three calls
later. The class is searchable; the filter is not applied.

So the certificate's **common name is the handle**, and it is `Granita` rather than the Mac's name:
renaming a Mac, or moving it to another network, must not orphan the identity. Every address this
Mac answers on goes in the subject alternative names, which is where RFC 5280 puts them and where
every modern client looks. The search is over certificates — where the label filter does work and
where the result can be asked for as bytes rather than as a `CFTypeRef` needing an unchecked cast —
and the private key is paired to it afterwards with `SecIdentityCreateWithCertificate`.

Two more Keychain facts are pinned in comments beside the code because each has one symptom and no
explanation: every query must say `kSecUseDataProtectionKeychain: false`, or the modern keychain
answers and refuses any ad-hoc-signed binary with `errSecMissingEntitlement`; and the private key is
**generated inside** the Keychain rather than imported, because `SecItemAdd` refuses a `SecKey` made
by `SecKeyCreateWithData` with `errSecInvalidItemRef`. The second is the better design anyway — the
private half never exists outside the Keychain, and this process only ever asks it to sign.

