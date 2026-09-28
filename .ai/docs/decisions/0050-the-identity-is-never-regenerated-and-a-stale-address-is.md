# The identity is never regenerated, and a stale address is the price

The certificate names every address the Mac had when it was created. Those change; the certificate
does not. Chasing them would rotate the pinned key every time the Mac joined a network, which
unpairs every device that has ever connected — a far worse failure than a subject alternative name
that no longer resolves, because the client matches on the pinned key rather than on the name.

