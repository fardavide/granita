# The phone checks the contract before it spends the code, never after

SPEC §8 says the client refuses to pair on an `apiVersion` mismatch. The order is the part worth
recording: `/v1/health` is read first and the code is spent second.

A pairing code lasts 120 seconds and works once. Discovering the skew from a 426 on the first read
route would mean the reader has already walked to the Mac, scanned a code, spent it, and has to go
back for another one to be told the same thing. Reading health costs one request against a route
that answers before pairing exists — which is the route's whole reason for existing.

Which end is behind is named rather than reported as "the versions differ", because one of them is
fixed by opening the App Store and the other by opening a Mac.

