# Mobile error reporting must work while the Mac is out of reach

On 12 September 2026, Davide replaced the attached-device/system-log workflow with a product
requirement: readable error screens and a button that copies diagnostics directly on his phone.
Raw NSError descriptions in an unavailable-content action slot had turned a TLS failure into a
large, low-contrast wall of text and separated the recovery button from the advice. Technical
details leave the visible layout; native recovery and "Copy Logs" remain together.

The report is bounded phone-side evidence from the current app session. Requests contribute
sanitized endpoints and structured error domains/codes, never authorization headers, pairing
credentials, bodies, source text or full NSError user-info dictionaries. Copying is local and
does not require a successful server connection, retry a request or spend another pairing code.
Its scope is stated in the copied text rather than implying access to system or Mac logs.

The current screen contributes a separately sanitized summary, so a discovery or Keychain failure
remains diagnosable even when no request failed. Keep only app-owned state/failure identifiers,
compatibility or stalled-step information, and numeric Keychain status, never raw associated
messages, saved-token contents or a reflected domain value. The report action is borderless blue
text without an icon; it does not compete with the prominent recovery button.

Davide explicitly waived the external design-tool handoff for this iteration and asked us to use
judgment, retaining a later design iteration if needed. This is a specific exception to the
screen-frame PR gate, not removal of that gate from the reusable workflow. The binding native
layout rules and verification of the clipboard effect still apply. No speculative TLS/ATS fix
is included in this change; the report is meant to obtain the missing evidence from the phone.

