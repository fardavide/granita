# The six words are a second credential, not a rendering of the code

An earlier draft derived the spoken code from the first six hexadecimal characters of the real one
and had no way to redeem it. That is not a fallback: it is a decoration under a QR that cannot be
typed in.

The words are now independently random and redeem the same pairing — spending either spends both,
so a photographed QR is worthless once the words have been used. The list is **128 words rather than
16**, because six words from sixteen is 24 bits: five guesses a minute from one address would take
years, and a hundred addresses on one network would not. 128 gives 42 bits, and the words are chosen
to be readable across a room — nothing homophonous, nothing a letter apart, no contested spellings.

What is typed is normalised before it is compared: nobody types the hyphens, and somebody reading
six words off a screen capitalises the first.

