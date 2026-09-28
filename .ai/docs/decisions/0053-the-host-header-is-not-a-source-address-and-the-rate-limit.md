# The `Host` header is not a source address, and the rate limit was counting the wrong thing

SPEC §8 asks for five failed attempts per minute **per source address**. The M2 implementation used
`request.head.authority`, which is what the client dialled — the same string for every device on the
network. So the limit was global, one misconfigured phone could lock out every other device, and the
connection log's "source" column said where each request went rather than where it came from.

The router now carries its own request context over `RemoteAddressRequestContext`, reading the peer
address off the channel. Confirmed against a real bound listener rather than the in-process test
client, which has no channel and reports nothing — and confirmed to be able to fail, by making the
accessor return a constant and watching the test go red.

