# The word diff measures similarity over non-whitespace tokens only

§6 sets a floor of 0.4 without saying what is measured. Counting the whitespace runs between words
would carry any two lines of similar shape over it — the runs match whatever the words are, so four
words against four different words scores 0.43 on spacing alone. Excluding them, the same pair scores
zero and is left unsegmented, which is what the floor is for: telling a line that was edited apart
from a line that was replaced.

The check is a token-bag overlap rather than the subsequence itself, so the quadratic comparison is
only run on pairs that can pass. A pure indentation change still isolates correctly, because
whitespace remains a token *inside* the comparison; it is only excluded from the similarity score.

