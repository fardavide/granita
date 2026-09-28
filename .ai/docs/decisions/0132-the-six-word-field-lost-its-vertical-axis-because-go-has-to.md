# The six-word field lost its vertical axis, because Go has to do something

`PairingWordsView` carried `submitLabel(.go)` and `onSubmit(onPair)` over a `TextField(axis:
.vertical)`. A field on a vertical axis takes Return as a newline and never submits, so the key that
reads as the action was not the action — the shape of dead control this project is named for, drawn
beautifully in four baselines the whole time.

The axis goes. §5 asks for one field with Go on it and that is now what ships, at the price the
vertical axis was buying: a six-word phrase is longer than one line at 390pt, so the field truncates
rather than wrapping. **That price is smaller than it looks, because the field was never the thing
being compared.** §5's argument is that the reader checks the *echo* against the Mac's line — a
different and far easier task than proofreading their own typing — and the echo wraps. Twenty of
that screen's baselines and the spine's `the-six-words` four were re-recorded against the new shape;
the field is the only thing in them that moved.

**And the normaliser now takes a line ending as a separator**, which is the defect underneath the
control one. A newline mid-phrase fused the two words either side into a token in no list, so the
echo read `apple⏎badge` and the unknown-word line named a word the reader never typed while pointing
them back at a Mac showing the right ones. Return was one way in and is now gone; **paste is the
other and cannot be**, and §5 makes paste the answer for the reader whose camera and whose Mac are
the same screen. `\r\n` is in the separator set beside `\r` and `\n` because a `Character` is a
grapheme cluster and the pair is one of them — a set holding only the halves matches neither.

