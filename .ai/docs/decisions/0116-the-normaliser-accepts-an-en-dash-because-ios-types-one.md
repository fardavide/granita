# The normaliser accepts an en dash, because iOS types one whether or not anyone meant to

`SpokenWords.normalised` split on space, hyphen, tab and the middle dot the Devices tab draws. iOS
smart punctuation turns a typed hyphen between two words into an **en dash**, so a reader typing the
code exactly as the Mac shows it would have been refused for punctuation the keyboard chose.

Fixed in two places rather than one, and both were needed. The field turns smart dashes off, which
stops it happening while typing; the normaliser accepts en and em dashes, which is what covers a
**paste** — the path the same-device case will actually take, and the one no field setting reaches.

Recorded because it is the second time this exact class of defect has been found here: the middle dot
was added for the same reason, that a code shown in a form the server will not accept is worse than no
fallback at all.

