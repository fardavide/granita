# The review is Markdown again, and this is the second reversal of that call

The exported review has now been Markdown, plain text, and Markdown. The first build fenced its
excerpts; design §7 overturned that in September 2026 on an argument worth restating, because it is
still half right — *the destination is a terminal on the Mac the phone is lying next to, and the
audience is an agent rather than a renderer*, so heading syntax is something a reader of the text has
to strip before it can act. Davide overturned it again on 16 September 2026: *"I want to use a proper
code block instead of a quote block, as it's doing now"*, and *"the code block should have an
identifier for the language, like the standard Markdown pattern."*

The reason the second call beats the first is that **§7's argument applied to headings and was applied
to fences by association.** They are not the same notation. A `#` is decoration — it says *this is
important* to a renderer and nothing at all to a parser. A fence is a delimiter: it says where code
starts, where it stops, and what language it is in, and it is the notation every agent this is pasted
to already reads. The `> ` it replaces was the costly one — a prefix on **every line**, which the
agent has to strip before the excerpt matches anything in the file, and which was chosen in the same
breath as `CommentSelection.quoted` deciding *not* to carry git's own `+`/`-` markers for exactly that
reason. One rule, applied to one of the two prefixes.

`#` headings did **not** come back. The document still opens with a sentence rather than a heading,
and a caveat is still a line of English outside the block. What changed is the one construct that
carries meaning a parser uses — and one more that is pure typography, below.

### A rule between comments, because a blank line was already spoken for

*"Let's use the section split format of the Markdown between each item. Otherwise it's a little bit
difficult to read the prompt as now."* The diagnosis is exact. A blank line is already this
document's separator **inside** a comment — the caveat, the fence and the reader's sentence are
stacked without one precisely so a comment reads as one thought — so the only thing left to divide
one comment from the next was another blank line, which is the same signal at the same weight. Four
comments became one wall. `---` is the one separator Markdown has that cannot be read as a paragraph
break, and it costs two lines.

The first rule also divides the note from the comments, on the same argument: the note is about the
change as a whole and everything under the rule is about particular lines.

### The heading lost its three facts, and that is an argument about where the text lands

It read `Review of uncommitted changes — swiftly, worktree main, 12 files`, and design §7's case for
the three was that the agent has one of them in hand and not the other two. Davide overturned it:
*"I don't think it's valuable to say the project name, the work tree, and the number of files. They
are contexts that the check session already has, so the default context line can only be 'review of
uncommitted changes'."*

**The two arguments are not about the same thing, which is why the second wins.** §7's is about what
the *document* contains in isolation. Davide's is about what the *session being pasted into* already
knows — and it is running in that checkout, with that worktree open, having just made those changes.
The line spent three facts telling it what it could already see, and the fourth, the only one it
could not derive, is the one that survives: what kind of thing is about to follow.

It also removes the document's last dependency on anything outside the comments. `ReviewFeedback`
takes no project, no worktree and no file count now, which made `ClientViewerModel`'s `projectName`
and `worktreeName` dead and deleted them. **One loose end is deliberately left**: the worktree sidebar
still resolves the project's name and offers it to the closure that opens a diff, where nothing takes
it. Removing that parameter reaches `WorktreeSidebarScreen`, `WorktreeSplitScreen` and their tests,
which is wider than a patch about a prompt should go, and it is recorded in `status.md` instead.

### The fence is measured, not assumed to be three backticks

The excerpt is arbitrary text and one of the files this repository is most often pointed at is its own
Markdown. A quoted line that is itself a fence closes the block where it sits, and everything after it
— the closing fence, the reader's comment, and every comment below — arrives as prose about code.
CommonMark's answer is taken literally: the outer fence is one backtick longer than the longest run
anywhere inside, so nothing in the excerpt can close it. The run is counted mid-line as well as at the
start, because over-counting costs one character and under-counting costs the document.

### The language is snapshotted on the comment, not looked up at export

`ReviewComment` already carries the path, the span and the excerpt for one reason — the agent is about
to change exactly those lines — and the language joins them on the same argument. It is the
extension-derived hint the server already sends and the highlighter is already given, so a fence and
the colours the reader saw agree by construction, and a comment whose file has left the change set
keeps the tag it had. Absent rather than guessed, which `LanguageHint` already decided: a fence tagged
with a language the file is not is worse for an agent than an untagged one.

It is optional on the wire as well as in the type, so a review written by 0.14.1 and read by 0.14.2
decodes with no migration — the synthesised decoder reads an absent key as nothing, and an untagged
fence is the right answer for a comment nothing ever claimed a language for. The reader who upgrades
mid-review has an afternoon's work in that store.

### Each comment is labelled, because the review is cleared and the labels are what is left

Davide asked for this and described the flow it serves: *"The user will write the comment, and then he
will copy the prompt and likely empty the comments. Then the user will see the points in the prompt
that he gives to the agent, and that should become its reference."* From the moment *Clear* is
pressed, the comments exist only in the text that was pasted — so an agent replying *"done, except C"*
is understood only if the document called something C. Without a label the reply has to quote a path
and a span back, which is the reading the reader picked up a phone to avoid.

Bijective base 26 rather than a letter that wraps: a review of an afternoon passes twenty-six
comments, and two comments called A is worse than no labels at all, because the reply then names one
of them and the reader cannot tell which.

**The style is Davide's choice and the setting for it is not built**, so 0.14.2 letters them and
states the default at one call site in `ClientViewerModel`. Letters because the instruction he wrote
the feature for names them: *"give me a reply for each one of them using the identifier letter."* The
two other halves of that request — the style, and a saved opening text replacing the document's first
line — both need a Settings surface the phone does not have, which is the same blocker
[#70](https://github.com/fardavide/granita/issues/70) has been sitting behind since 0.7.0. Davide
scoped that work in the same exchange: the setting is editable **from the phone and from the Mac and
synced between them**, and it lands alongside
[#64](https://github.com/fardavide/granita/issues/64), which moves the comments themselves off the
phone. That is a wire change and a design round trip, and it is a slice of its own.

