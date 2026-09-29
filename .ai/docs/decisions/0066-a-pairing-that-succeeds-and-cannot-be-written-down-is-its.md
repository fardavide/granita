# A pairing that succeeds and cannot be written down is its own outcome

The Mac keeps a hash of the token and the phone keeps the only copy, so a `SecItemAdd` that fails
after `/v1/pair` has answered leaves the worst state this app has: the Mac holds a device record for
a credential nothing can produce, and every subsequent request is `unauthorized` for a reason no
screen could explain. Reported as an ordinary failure it would send the reader round the same loop
forever.

So it is a case of its own on the connection model, and what it has to say is different from every
other failure: revoke the device on the Mac before pairing again.

