# TLS diagnostics record our decision, not a completed secure connection

Davide's 0.11.0 (136) report captured a tailnet request failing with `-1200` but no evidence of
whether the phone received Granita's trust callback or rejected its saved pin. On 12 September
2026 he approved a diagnostic-only follow-up, rather than another speculative connection fix.

Paired sessions now record their trust callback's outcome before handing the answer back to
URLSession: pin matched, pin mismatched, trust unavailable or public key unavailable. An unusable
P-256 key is not a mismatched pin. These events share the existing bounded, phone-side journal;
only the HTTPS host/port and app-owned outcome are retained, never certificates, fingerprints,
credentials, challenge errors or trust dictionaries. First-contact pairing is outside this change.

An accepted pin means Granita supplied a trust credential; it does not prove URLSession completed
TLS or that a request succeeded. Request errors remain in the report. Absence of a trust event
is evidence only of no callback recorded in this app session, not proof of any particular ATS
policy failure; pooled connections need not challenge again for every request.

Certificate acceptance remains pin-only, with no default trust evaluation introduced and no ATS,
certificate, identity or server configuration changed. The report must supply missing evidence
before a security-policy change is proposed.

