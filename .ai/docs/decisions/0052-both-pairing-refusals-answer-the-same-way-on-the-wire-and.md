# Both pairing refusals answer the same way on the wire and differently in the log

`/v1/pair` is the one route an unpaired device may reach, so it is the one route an attacker may
reach. A caller told apart "that was never a code" from "that was a code, too late" has an oracle
for whether it is guessing in the right shape at all, so both come back `pairingExpired`.

The connection log gets the difference, because its only reader is the person standing at the Mac
and the two mean different things to them — type it again, against be quicker. That panel is the
reason the distinction is worth keeping at all rather than collapsing at the source.

