# `--pair` reissues, because a code cannot be asked for from outside the process

Pairing codes live in the actor serving requests, so there is no way for a second invocation of
`granita-server` to hand one out — and there is no QR in a terminal. `--pair` therefore prints an
invitation at startup and a fresh one as each expires.

It exists so the TLS and pairing path is exercisable before the pairing screen is designed, which is
what let this slice be verified end to end: `curl --pinnedpubkey` over the advertised port, the
six-word code redeemed for a token, and an authenticated route read back. Noisy by design; it is a
debugging flag on a debugging tool, and two minutes is not long enough to fumble a phone out of a
pocket.

