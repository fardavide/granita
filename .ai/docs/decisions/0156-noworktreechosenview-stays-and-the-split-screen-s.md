# `NoWorktreeChosenView` stays, and the split screen's destination stays doubled

Both were left open by 0.3.0 for Davide, and both are settled as they stood.

The empty detail column keeps its unavailable-content view, because design §2 asks for one in as many
words and the composition that ships still has it. The doubled `navigationDestination` stays doubled,
because what it settles is which of two containers claims a tap, and removing a declaration to find
out is exactly how this app shipped a row that did nothing. It costs one duplicated line and it is
correct in both layouts; the finger that settles it is the same one the device afternoon owes §4.

