# Timestamps are ISO 8601 because both ends say so, not because a framework does

M2 left this open deliberately: the date format on the wire was whatever Hummingbird's encoder
defaulted to, with a test reading the raw JSON so a change would be red rather than silent, and a
note that pinning it belonged to the next change in the API module. This is that change, and the
reason it could not stay implicit is that the phone has to pick a decoding strategy explicitly —
there is no default to inherit on that side.

Hummingbird's default happens to be `.iso8601` already, which is exactly why leaving it alone was the
wrong answer: a dependency upgrade that changed it would move only one end, and the symptom is every
worktree showing as modified in 1970. Both the request context and the client's decoder now say
`.iso8601` in as many words, so a change to either is a change somebody wrote.

